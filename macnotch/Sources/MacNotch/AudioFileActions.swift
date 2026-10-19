@preconcurrency import AVFoundation
import Foundation

private final class AudioExportCallbackBox: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
}

struct AudioConversionResult {
    let outputs: [URL]
    let failures: [(URL, String)]
}

enum AudioFileActions {
    static let supportedExtensions: Set<String> = ["wav", "aif", "aiff", "caf"]

    static func isSupportedAudio(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func convertedDestination(for source: URL, in folder: URL, fileManager: FileManager = .default) -> URL {
        availableURL(stem: source.deletingPathExtension().lastPathComponent + "-converted", in: folder, fileManager: fileManager)
    }

    static func convertToM4A(_ sources: [URL], into folder: URL, fileManager: FileManager = .default) async -> AudioConversionResult {
        var outputs: [URL] = []
        var failures: [(URL, String)] = []
        let uniqueSources = sources.map(\.standardizedFileURL).reduce(into: [URL]()) { result, source in
            if !result.contains(source) { result.append(source) }
        }

        for source in uniqueSources {
            guard isSupportedAudio(source), fileManager.fileExists(atPath: source.path) else {
                failures.append((source, "Unsupported audio type or source file is missing."))
                continue
            }
            let destination = convertedDestination(for: source, in: folder, fileManager: fileManager)
            do {
                try await convertOne(source, to: destination)
                outputs.append(destination)
            } catch {
                try? fileManager.removeItem(at: destination)
                failures.append((source, error.localizedDescription))
            }
        }
        return AudioConversionResult(outputs: outputs, failures: failures)
    }

    private static func convertOne(_ source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard try await asset.load(.isPlayable) else { throw AudioConversionError.unreadable }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw AudioConversionError.noAudioTrack }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioConversionError.exportUnavailable
        }
        guard exporter.supportedFileTypes.contains(.m4a) else { throw AudioConversionError.m4aUnavailable }
        if #available(macOS 15.0, *) {
            try await exporter.export(to: destination, as: .m4a)
        } else {
            try await exportForMacOS14(exporter, to: destination)
        }
        let sourceSize = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let outputSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard outputSize > 0 else { throw AudioConversionError.missingOutput }
        guard outputSize < sourceSize else {
            try? FileManager.default.removeItem(at: destination)
            throw AudioConversionError.noSavings
        }
    }

    @available(macOS, introduced: 14.0, deprecated: 15.0, message: "Compatibility path for macOS 14")
    private static func exportForMacOS14(_ exporter: AVAssetExportSession, to destination: URL) async throws {
        exporter.outputURL = destination
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = true
        let callbackBox = AudioExportCallbackBox(exporter)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            callbackBox.session.exportAsynchronously {
                switch callbackBox.session.status {
                case .completed: continuation.resume()
                case .cancelled: continuation.resume(throwing: AudioConversionError.cancelled)
                case .failed: continuation.resume(throwing: callbackBox.session.error ?? AudioConversionError.exportFailed)
                default: continuation.resume(throwing: AudioConversionError.exportFailed)
                }
            }
        }
    }

    private static func availableURL(stem: String, in folder: URL, fileManager: FileManager) -> URL {
        var suffix = 1
        while true {
            let ending = suffix == 1 ? "" : "-\(suffix)"
            let candidate = folder.appendingPathComponent("\(stem)\(ending).m4a")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
    }
}

private enum AudioConversionError: LocalizedError {
    case unreadable
    case noAudioTrack
    case exportUnavailable
    case m4aUnavailable
    case missingOutput
    case noSavings
    case exportFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unreadable: "macOS could not read this audio file."
        case .noAudioTrack: "This file has no audio track to convert."
        case .exportUnavailable: "macOS could not prepare an audio converter."
        case .m4aUnavailable: "This audio cannot be exported as M4A on this Mac."
        case .missingOutput: "The converted file was not created."
        case .noSavings: "This audio is already compact enough; the M4A copy would not be smaller, so no copy was kept."
        case .exportFailed: "Audio conversion failed."
        case .cancelled: "Audio conversion was canceled."
        }
    }
}
