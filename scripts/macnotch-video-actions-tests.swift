import AVFoundation
import CoreVideo
import Foundation
import ImageIO

@main
struct MacNotchVideoActionsTests {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchVideoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let movie = folder.appendingPathComponent("demo.mov")
        guard VideoFileActions.isSupportedVideo(movie),
              VideoFileActions.isSupportedVideo(folder.appendingPathComponent("clip.MP4")),
              !VideoFileActions.isSupportedVideo(folder.appendingPathComponent("audio.m4a")),
              !VideoFileActions.isSupportedVideo(folder.appendingPathComponent("notes.txt")) else {
            fatalError("Video format filtering should accept MOV/MP4/M4V and reject unrelated media")
        }

        let first = VideoFileActions.compressedDestination(for: movie, in: folder)
        guard first.lastPathComponent == "demo-compressed.mp4" else { fatalError("Unexpected first output name") }
        try Data("existing output".utf8).write(to: first)
        let second = VideoFileActions.compressedDestination(for: movie, in: folder)
        guard second.lastPathComponent == "demo-compressed-2.mp4",
              try Data(contentsOf: first) == Data("existing output".utf8) else {
            fatalError("Compression destination selection must avoid overwriting existing files")
        }
        let firstGIF = VideoFileActions.gifDestination(for: movie, in: folder)
        guard firstGIF.lastPathComponent == "demo-animated.gif" else { fatalError("Unexpected first GIF output name") }
        try Data("existing GIF".utf8).write(to: firstGIF)
        let secondGIF = VideoFileActions.gifDestination(for: movie, in: folder)
        guard secondGIF.lastPathComponent == "demo-animated-2.gif",
              try Data(contentsOf: firstGIF) == Data("existing GIF".utf8) else {
            fatalError("GIF destination selection must avoid overwriting existing files")
        }
        let firstTrim = VideoFileActions.trimmedDestination(for: movie, in: folder)
        guard firstTrim.lastPathComponent == "demo-trimmed.mp4" else { fatalError("Unexpected first trimmed output name") }
        try Data("existing trimmed video".utf8).write(to: firstTrim)
        let secondTrim = VideoFileActions.trimmedDestination(for: movie, in: folder)
        guard secondTrim.lastPathComponent == "demo-trimmed-2.mp4",
              try Data(contentsOf: firstTrim) == Data("existing trimmed video".utf8) else {
            fatalError("Trim destination selection must avoid overwriting existing files")
        }

        let unsupported = folder.appendingPathComponent("notes.txt")
        try Data("not a movie".utf8).write(to: unsupported)
        let invalid = await VideoFileActions.compress([unsupported, unsupported], into: folder)
        let invalidGIF = await VideoFileActions.createGIFs([unsupported, unsupported], into: folder)
        let invalidTrim = await VideoFileActions.trimVideos([unsupported, unsupported], startSeconds: 0, into: folder)
        guard invalid.outputs.isEmpty, invalid.failures.count == 1,
              invalidGIF.outputs.isEmpty, invalidGIF.failures.count == 1,
              invalidTrim.outputs.isEmpty, invalidTrim.failures.count == 1,
              try Data(contentsOf: first) == Data("existing output".utf8),
              try Data(contentsOf: firstGIF) == Data("existing GIF".utf8),
              try Data(contentsOf: firstTrim) == Data("existing trimmed video".utf8),
              FileManager.default.fileExists(atPath: unsupported.path) else {
            fatalError("Invalid/duplicate videos should be reported once without changing sources or existing output")
        }

        try createNoisyMovie(at: movie)
        let sourceSize = try movie.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let gifs = await VideoFileActions.createGIFs([movie, movie], into: folder)
        guard gifs.outputs.count == 1, gifs.failures.isEmpty,
              FileManager.default.fileExists(atPath: movie.path),
              let gif = gifs.outputs.first,
              let gifSource = CGImageSourceCreateWithURL(gif as CFURL, nil),
              CGImageSourceGetCount(gifSource) >= 8,
              try Data(contentsOf: firstGIF) == Data("existing GIF".utf8) else {
            fatalError("Video-to-GIF conversion should produce one animated, collision-safe copy while preserving the source")
        }
        let trimmed = await VideoFileActions.trimVideos([movie, movie], startSeconds: 0.2, endSeconds: 0.8, into: folder)
        guard trimmed.outputs.count == 1, trimmed.failures.isEmpty,
              FileManager.default.fileExists(atPath: movie.path),
              let trimmedOutput = trimmed.outputs.first,
              trimmedOutput.lastPathComponent == "demo-trimmed-2.mp4",
              try Data(contentsOf: firstTrim) == Data("existing trimmed video".utf8),
              try await AVURLAsset(url: trimmedOutput).load(.isPlayable) else {
            fatalError("Trimming should create one playable collision-safe copy, deduplicate input, and preserve the source")
        }
        let trimmedAssetDuration = try await AVURLAsset(url: trimmedOutput).load(.duration)
        let trimmedDuration = trimmedAssetDuration.seconds
        guard trimmedDuration > 0.45, trimmedDuration <= 0.65 else {
            fatalError("The exported video should contain the requested time range")
        }
        let invalidRange = await VideoFileActions.trimVideos([movie, movie], startSeconds: 0.9, endSeconds: 0.1, into: folder)
        guard invalidRange.outputs.isEmpty, invalidRange.failures.count == 1,
              FileManager.default.fileExists(atPath: movie.path) else {
            fatalError("Invalid trim ranges should be rejected once without changing the source")
        }
        let compressed = await VideoFileActions.compress([movie, movie], into: folder)
        guard compressed.outputs.count == 1, compressed.failures.isEmpty,
              FileManager.default.fileExists(atPath: movie.path),
              let output = compressed.outputs.first,
              let outputSize = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              outputSize < sourceSize,
              try await AVURLAsset(url: output).load(.isPlayable) else {
            fatalError("Video compression should create one playable smaller copy, deduplicate the source, and preserve the original")
        }
        print("MacNotch video action checks passed")
    }

    private static func createNoisyMovie(at url: URL) throws {
        let width = 640
        let height = 360
        let frameCount = 30
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000]
        ])
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])
        guard writer.canAdd(videoInput) else { fatalError("Could not configure generated-video test writer") }
        writer.add(videoInput)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "MacNotchVideoTests", code: 1) }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<frameCount {
            while !videoInput.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            var optionalBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool!, &optionalBuffer) == kCVReturnSuccess,
                  let buffer = optionalBuffer else { fatalError("Could not allocate generated video frame") }
            CVPixelBufferLockBaseAddress(buffer, [])
            let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let byteCount = CVPixelBufferGetBytesPerRow(buffer) * height
            var seed = UInt32(frame + 1) &* 2_654_435_761
            for index in stride(from: 0, to: byteCount, by: 4) {
                seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
                bytes[index] = UInt8(truncatingIfNeeded: seed)
                bytes[index + 1] = UInt8(truncatingIfNeeded: seed >> 8)
                bytes[index + 2] = UInt8(truncatingIfNeeded: seed >> 16)
                bytes[index + 3] = 255
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else {
                throw writer.error ?? NSError(domain: "MacNotchVideoTests", code: 2)
            }
        }
        videoInput.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "MacNotchVideoTests", code: 3) }
    }
}
