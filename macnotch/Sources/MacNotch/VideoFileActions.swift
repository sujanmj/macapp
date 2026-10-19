@preconcurrency import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

private final class ExportSessionCallbackBox: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
}

struct VideoCompressionResult {
    let outputs: [URL]
    let failures: [(URL, String)]
}

struct VideoGIFResult {
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

    static func gifDestination(for source: URL, in folder: URL, fileManager: FileManager = .default) -> URL {
        let stem = source.deletingPathExtension().lastPathComponent + "-animated"
        return availableURL(stem: stem, extension: "gif", in: folder, fileManager: fileManager)
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

    static func createGIFs(
        _ sources: [URL],
        into folder: URL,
        framesPerSecond: Int = 10,
        maximumDuration: TimeInterval = 15,
        maximumPixelSize: Int = 480,
        fileManager: FileManager = .default
    ) async -> VideoGIFResult {
        var outputs: [URL] = []
        var failures: [(URL, String)] = []
        let uniqueSources = sources.map(\.standardizedFileURL).reduce(into: [URL]()) { result, source in
            if !result.contains(source) { result.append(source) }
        }

        for source in uniqueSources {
            guard isSupportedVideo(source), fileManager.fileExists(atPath: source.path) else {
                failures.append((source, "Unsupported video type or source file is missing."))
                continue
            }
            let destination = gifDestination(for: source, in: folder, fileManager: fileManager)
            do {
                try await createGIFOne(
                    source,
                    to: destination,
                    framesPerSecond: framesPerSecond,
                    maximumDuration: maximumDuration,
                    maximumPixelSize: maximumPixelSize
                )
                outputs.append(destination)
            } catch {
                try? fileManager.removeItem(at: destination)
                failures.append((source, error.localizedDescription))
            }
        }
        return VideoGIFResult(outputs: outputs, failures: failures)
    }

    private static func createGIFOne(
        _ source: URL,
        to destination: URL,
        framesPerSecond: Int,
        maximumDuration: TimeInterval,
        maximumPixelSize: Int
    ) async throws {
        let asset = AVURLAsset(url: source)
        guard try await asset.load(.isPlayable) else { throw VideoGIFError.unreadable }
        let assetDuration = try await asset.load(.duration)
        let duration = assetDuration.seconds
        guard duration.isFinite, duration > 0 else { throw VideoGIFError.invalidDuration }

        let fps = min(20, max(1, framesPerSecond))
        let frameDuration = 1.0 / Double(fps)
        let durationToConvert = min(duration, max(frameDuration, maximumDuration))
        let frameCount = max(1, Int(ceil(durationToConvert * Double(fps))))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: max(1, maximumPixelSize), height: max(1, maximumPixelSize))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let loopProperties: [CFString: Any] = [kCGImagePropertyGIFLoopCount: 0]
        let destinationProperties: [CFString: Any] = [kCGImagePropertyGIFDictionary: loopProperties]
        guard let imageDestination = CGImageDestinationCreateWithURL(
            destination as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            destinationProperties as CFDictionary
        ) else { throw VideoGIFError.exportUnavailable }

        let delay = min(1, max(0.02, frameDuration))
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay,
                kCGImagePropertyGIFUnclampedDelayTime: delay
            ] as [CFString: Any]
        ]
        for frameIndex in 0..<frameCount {
            let seconds = min(Double(frameIndex) * frameDuration, max(0, duration - 0.001))
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            let image = try await image(at: time, from: generator)
            CGImageDestinationAddImage(imageDestination, image, frameProperties as CFDictionary)
        }
        guard CGImageDestinationFinalize(imageDestination),
              let imageSource = CGImageSourceCreateWithURL(destination as CFURL, nil),
              CGImageSourceGetCount(imageSource) > 0 else {
            throw VideoGIFError.exportFailed
        }
    }

    private static func image(at time: CMTime, from generator: AVAssetImageGenerator) async throws -> CGImage {
        if #available(macOS 15.0, *) {
            return try await generator.image(at: time).image
        }
        return try copyCGImage(at: time, from: generator)
    }

    @available(macOS, introduced: 14.0, deprecated: 15.0, message: "Compatibility path for macOS 14")
    private static func copyCGImage(at time: CMTime, from generator: AVAssetImageGenerator) throws -> CGImage {
        try generator.copyCGImage(at: time, actualTime: nil)
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

private enum VideoGIFError: LocalizedError {
    case unreadable
    case invalidDuration
    case exportUnavailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: "macOS could not read this video."
        case .invalidDuration: "This video has no usable duration."
        case .exportUnavailable: "macOS could not prepare an animated GIF."
        case .exportFailed: "The animated GIF could not be written."
        }
    }
}
