import AppKit
import AVFoundation
import Foundation
import Speech

private final class AssetExportBox: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
}

private struct LocalSpeechTranscript {
    let text: String
    let cues: [SubtitleCue]
}

@MainActor
final class MeetingTranscriber: ObservableObject {
    @Published private(set) var isTranscribing = false
    @Published private(set) var message = "Transcription runs on this Mac when on-device speech recognition is available."
    @Published private(set) var transcriptURL: URL?
    @Published private(set) var subtitleURL: URL?

    func transcribe(_ movieURL: URL) async {
        guard !isTranscribing else { return }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            message = "Speech recognition is currently unavailable for this language."
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            message = "On-device speech recognition is unavailable for this language. No audio was uploaded."
            return
        }

        isTranscribing = true
        transcriptURL = nil
        subtitleURL = nil
        message = "Requesting speech-recognition access…"
        defer { isTranscribing = false }

        let authorization = await requestAuthorization()
        guard authorization == .authorized else {
            message = authorization == .denied
                ? "Allow Speech Recognition for MacNotch in System Settings, then try again."
                : "Speech-recognition permission was not granted."
            return
        }

        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacNotch-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: audioURL) }
        do {
            message = "Preparing the recording’s audio locally…"
            try await extractAudio(from: movieURL, to: audioURL)
            message = "Transcribing locally… This may take a while for long recordings."
            let transcript = try await recognize(audioURL: audioURL, recognizer: recognizer)
            guard !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                message = "No speech was recognized in this recording."
                return
            }
            let outputURL = movieURL.deletingPathExtension().appendingPathExtension("txt")
            try transcript.text.write(to: outputURL, atomically: true, encoding: .utf8)
            transcriptURL = outputURL
            let captionsURL = movieURL.deletingPathExtension().appendingPathExtension("srt")
            let subtitles = SubtitleFormatter.srt(transcript.cues)
            if !subtitles.isEmpty {
                try subtitles.write(to: captionsURL, atomically: true, encoding: .utf8)
                subtitleURL = captionsURL
            }
            message = subtitleURL == nil
                ? "Transcript saved beside the recording. No timed subtitle cues were available."
                : "Transcript and timed subtitles saved beside the recording. Audio was processed on this Mac."
        } catch {
            message = "Could not transcribe this recording: \(error.localizedDescription)"
        }
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private func extractAudio(from movieURL: URL, to audioURL: URL) async throws {
        let asset = AVURLAsset(url: movieURL)
        guard try await !asset.loadTracks(withMediaType: .audio).isEmpty else {
            throw TranscriptionError.noAudio
        }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.audioExportUnavailable
        }
        let exportBox = AssetExportBox(exporter)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exporter.outputURL = audioURL
            exporter.outputFileType = .m4a
            exporter.exportAsynchronously {
                switch exportBox.session.status {
                case .completed: continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: exportBox.session.error ?? TranscriptionError.audioExportFailed)
                default: continuation.resume(throwing: TranscriptionError.audioExportFailed)
                }
            }
        }
    }

    private func recognize(audioURL: URL, recognizer: SFSpeechRecognizer) async throws -> LocalSpeechTranscript {
        try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false
            var task: SFSpeechRecognitionTask?
            task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    task?.cancel()
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    let transcription = result.bestTranscription
                    let cues = transcription.segments.map { segment in
                        SubtitleCue(text: segment.substring, start: segment.timestamp, duration: segment.duration)
                    }
                    continuation.resume(returning: LocalSpeechTranscript(text: transcription.formattedString, cues: cues))
                }
            }
        }
    }
}

private enum TranscriptionError: LocalizedError {
    case noAudio
    case audioExportUnavailable
    case audioExportFailed

    var errorDescription: String? {
        switch self {
        case .noAudio: "This recording has no audio track. Enable system audio or microphone before recording."
        case .audioExportUnavailable: "macOS could not prepare this recording’s audio."
        case .audioExportFailed: "macOS could not extract audio from this recording."
        }
    }
}
