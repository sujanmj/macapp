@preconcurrency import AVFoundation
import Foundation

private final class ExportSessionCallbackBox: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
}

struct VideoCompressionResult {
    let outputs: [URL]
    let failures: [(URL, String)]
}

enum VideoFileActions {
    static let supportedExtensions: Set<String> = ["mov", "mp4", "m4v"]

    static func isSupportedVideo(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func compressedDestination(for source: URL, in folder: URL, fileManager: FileManager = .default) -> URL {
        let stem = source.deletingPathExtension().lastPathComponent + "-compressed"
        return availableURL(stem: stem, extension: "mp4", in: folder, fileManager: fileManager)
    }

    static func compress(_ sources: [URL], into folder: URL, fileManager: FileManager = .default) async -> VideoCompressionResult {
        var outputs: [URL] = []
        var failures: [(URL, String)] = []
        let normalized = sources.map(\.standardizedFileURL)
        let uniqueSources = normalized.reduce(into: [URL]()) { result, source in
            if !result.contains(source) { result.append(source) }
        }

        for source in uniqueSources {
            guard isSupportedVideo(source), fileManager.fileExists(atPath: source.path) else {
                failures.append((source, "Unsupported video type or source file is missing."))
                continue
            }
            let destination = compressedDestination(for: source, in: folder, fileManager: fileManager)
            do {
                try await compressOne(source, to: destination)
                outputs.append(destination)
            } catch {
                try? fileManager.removeItem(at: destination)
                failures.append((source, error.localizedDescription))
            }
        }
        return VideoCompressionResult(outputs: outputs, failures: failures)
    }

    private static func compressOne(_ source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        let playable = try await asset.load(.isPlayable)
        guard playable else { throw VideoCompressionError.unreadable }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw VideoCompressionError.exportUnavailable
        }
        guard exporter.supportedFileTypes.contains(.mp4) else { throw VideoCompressionError.mp4Unavailable }
        if #available(macOS 15.0, *) {
            try await exporter.export(to: destination, as: .mp4)
        } else {
            try await exportForMacOS14(exporter, to: destination)
        }
        let sourceSize = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let destinationSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard destinationSize > 0 else { throw VideoCompressionError.missingOutput }
        guard destinationSize < sourceSize else {
            try? FileManager.default.removeItem(at: destination)
            throw VideoCompressionError.noSavings
        }
    }

    @available(macOS, introduced: 14.0, deprecated: 15.0, message: "Compatibility path for macOS 14")
    private static func exportForMacOS14(_ exporter: AVAssetExportSession, to destination: URL) async throws {
        exporter.outputURL = destination
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        let callbackBox = ExportSessionCallbackBox(exporter)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            callbackBox.session.exportAsynchronously {
                switch callbackBox.session.status {
                case .completed: continuation.resume()
                case .cancelled: continuation.resume(throwing: VideoCompressionError.cancelled)
                case .failed: continuation.resume(throwing: callbackBox.session.error ?? VideoCompressionError.exportFailed)
                default: continuation.resume(throwing: VideoCompressionError.exportFailed)
                }
            }
        }
    }

    private static func availableURL(stem: String, extension fileExtension: String, in folder: URL, fileManager: FileManager) -> URL {
        var suffix = 1
        while true {
            let ending = suffix == 1 ? "" : "-\(suffix)"
            let candidate = folder.appendingPathComponent("\(stem)\(ending).\(fileExtension)")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
    }
}

private enum VideoCompressionError: LocalizedError {
    case unreadable
    case exportUnavailable
    case mp4Unavailable
    case missingOutput
    case noSavings
    case exportFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unreadable: "macOS could not read this video."
        case .exportUnavailable: "macOS could not prepare a video compressor."
        case .mp4Unavailable: "This video cannot be exported as MP4 on this Mac."
        case .missingOutput: "The compressed file was not created."
        case .noSavings: "This video is already compact enough; the MP4 copy would not be smaller, so no copy was kept."
        case .exportFailed: "Video compression failed."
        case .cancelled: "Video compression was canceled."
        }
    }
}
