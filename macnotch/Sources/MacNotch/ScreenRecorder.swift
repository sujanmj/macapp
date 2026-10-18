import AVFoundation
import AppKit
import Foundation
import ScreenCaptureKit
import SwiftUI

private final class ScreenRecordingOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.sujanmj.macnotch.recording-writer", qos: .userInitiated)
    let writer: AVAssetWriter
    let destination: URL
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?
    private let microphoneInput: AVAssetWriterInput?
    private var hasStartedSession = false
    private var hasFailed = false
    var onFailure: ((String) -> Void)?

    init(destination: URL, width: Int, height: Int, includeSystemAudio: Bool, includeMicrophone: Bool) throws {
        self.destination = destination
        writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        videoInput.expectsMediaDataInRealTime = true
        if includeSystemAudio {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            input.expectsMediaDataInRealTime = true
            audioInput = input
        } else {
            audioInput = nil
        }
        if includeMicrophone {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            input.expectsMediaDataInRealTime = true
            microphoneInput = input
        } else {
            microphoneInput = nil
        }
        super.init()
        guard writer.canAdd(videoInput) else { throw RecordingError.writerInputUnavailable }
        writer.add(videoInput)
        if let audioInput {
            guard writer.canAdd(audioInput) else { throw RecordingError.writerInputUnavailable }
            writer.add(audioInput)
        }
        if let microphoneInput {
            guard writer.canAdd(microphoneInput) else { throw RecordingError.writerInputUnavailable }
            writer.add(microphoneInput)
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        switch type {
        case .screen:
            if writer.status == .unknown {
                guard writer.startWriting() else { fail(writer.error?.localizedDescription ?? "The movie file could not be started."); return }
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                hasStartedSession = true
            }
            guard writer.status == .writing, videoInput.isReadyForMoreMediaData else { return }
            if !videoInput.append(sampleBuffer) { fail(writer.error?.localizedDescription ?? "A screen frame could not be saved.") }
        case .audio:
            guard hasStartedSession, writer.status == .writing,
                  let audioInput, audioInput.isReadyForMoreMediaData else { return }
            if !audioInput.append(sampleBuffer) { fail(writer.error?.localizedDescription ?? "System audio could not be saved.") }
        default:
            if #available(macOS 15.0, *), type == .microphone,
               hasStartedSession, writer.status == .writing,
               let microphoneInput, microphoneInput.isReadyForMoreMediaData,
               !microphoneInput.append(sampleBuffer) {
                fail(writer.error?.localizedDescription ?? "Microphone audio could not be saved.")
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        queue.async { [weak self] in self?.fail(message) }
    }

    func finish() async -> URL? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.hasStartedSession else {
                    self.writer.cancelWriting()
                    try? FileManager.default.removeItem(at: self.destination)
                    continuation.resume(returning: nil)
                    return
                }
                guard self.writer.status == .writing else {
                    let completed = self.writer.status == .completed
                    if !completed { try? FileManager.default.removeItem(at: self.destination) }
                    continuation.resume(returning: completed ? self.destination : nil)
                    return
                }
                self.videoInput.markAsFinished()
                self.audioInput?.markAsFinished()
                self.microphoneInput?.markAsFinished()
                self.writer.finishWriting {
                    let completed = self.writer.status == .completed
                    if !completed { try? FileManager.default.removeItem(at: self.destination) }
                    continuation.resume(returning: completed ? self.destination : nil)
                }
            }
        }
    }

    func cancel() {
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: destination)
    }

    private func fail(_ message: String) {
        guard !hasFailed else { return }
        hasFailed = true
        Task { @MainActor in onFailure?(message) }
    }
}

private enum RecordingError: LocalizedError {
    case noDisplay
    case writerInputUnavailable

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display is available to record."
        case .writerInputUnavailable: "macOS could not configure the recording file."
        }
    }
}

@MainActor
final class ScreenRecorderController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed = 0
    @Published private(set) var message = "Record the primary display to Movies/MacNotch Recordings."
    @Published private(set) var latestRecording: URL?

    private var stream: SCStream?
    private var output: ScreenRecordingOutput?
    private var startedAt: Date?
    private var timer: Timer?

    func start(includeSystemAudio: Bool, includeMicrophone: Bool) async {
        guard !isRecording else { return }
        if includeMicrophone {
            guard #available(macOS 15.0, *) else {
                message = "Microphone recording requires macOS 15 or later."
                return
            }
        }
        message = "Preparing screen capture…"
        var pendingOutput: ScreenRecordingOutput?
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mainDisplayID = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
                throw RecordingError.noDisplay
            }

            let folder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Movies/MacNotch Recordings", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let destination = folder.appendingPathComponent("MacNotch-\(formatter.string(from: Date())).mov")

            let output = try ScreenRecordingOutput(destination: destination, width: display.width, height: display.height,
                                                   includeSystemAudio: includeSystemAudio, includeMicrophone: includeMicrophone)
            pendingOutput = output
            output.onFailure = { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.message = "Recording stopped: \(error)"
                    await self.stop()
                }
            }
            let appToExclude = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: appToExclude, exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.queueDepth = 5
            configuration.showsCursor = true
            configuration.excludesCurrentProcessAudio = true
            configuration.capturesAudio = includeSystemAudio
            if includeSystemAudio {
                configuration.sampleRate = 48_000
                configuration.channelCount = 2
            }
            if #available(macOS 15.0, *), includeMicrophone { configuration.captureMicrophone = true }

            let stream = SCStream(filter: filter, configuration: configuration, delegate: output)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
            if includeSystemAudio { try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: output.queue) }
            if #available(macOS 15.0, *), includeMicrophone {
                try stream.addStreamOutput(output, type: .microphone, sampleHandlerQueue: output.queue)
            }
            try await stream.startCapture()
            self.stream = stream
            self.output = output
            isRecording = true
            startedAt = Date()
            elapsed = 0
            let audio = [includeSystemAudio ? "system audio" : nil, includeMicrophone ? "microphone" : nil].compactMap { $0 }.joined(separator: " and ")
            message = "Recording the primary display\(audio.isEmpty ? " without audio" : " with \(audio)")."
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let startedAt = self.startedAt else { return }
                    self.elapsed = max(0, Int(Date().timeIntervalSince(startedAt)))
                }
            }
        } catch {
            pendingOutput?.cancel()
            isRecording = false
            message = "Could not start recording. Allow MacNotch in System Settings → Privacy & Security → Screen Recording, then try again. (\(error.localizedDescription))"
        }
    }

    func stop() async {
        guard isRecording || stream != nil else { return }
        isRecording = false
        timer?.invalidate(); timer = nil
        do { try await stream?.stopCapture() } catch { message = "Capture stopped with a warning: \(error.localizedDescription)" }
        if let url = await output?.finish() {
            latestRecording = url
            message = "Saved recording to Movies/MacNotch Recordings."
        } else {
            message = "The recording ended before any usable video frames were captured. Check Screen Recording permission and try again."
        }
        stream = nil
        output = nil
        startedAt = nil
    }

    func openRecordingsFolder() {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/MacNotch Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
