import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo

/// Samples sparse pixels of a downscaled display capture. No frame is stored or uploaded.
final class ScreenLuminance: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "lumaflow.capture")
    var onSample: ((Double) -> Void)?

    func start() async throws {
        stop()
        let displays = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true).displays
        guard let display = displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? displays.first else {
            throw NSError(domain: "LumaFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "No shareable display found."])
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = 160
        configuration.height = 100
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2)
        configuration.queueDepth = 2
        configuration.showsCursor = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        guard let old = stream else { return }
        stream = nil
        Task { try? await old.stopCapture() }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA else { return }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let raw = base.assumingMemoryBound(to: UInt8.self)
        var total = 0.0
        var samples = 0
        for y in Swift.stride(from: 2, to: height, by: 5) {
            for x in Swift.stride(from: 2, to: width, by: 5) {
                let index = y * bytesPerRow + x * 4
                let b = Double(raw[index]) / 255
                let g = Double(raw[index + 1]) / 255
                let r = Double(raw[index + 2]) / 255
                total += 0.2126 * r + 0.7152 * g + 0.0722 * b
                samples += 1
            }
        }
        guard samples > 0 else { return }
        let mean = total / Double(samples)
        DispatchQueue.main.async { [weak self] in self?.onSample?(mean) }
    }
}
