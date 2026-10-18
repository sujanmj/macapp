import AppKit

@main
struct MacNotchCaptureTests {
    static func main() async throws {
        let width = 1400
        let height = 360
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Could not create the local OCR fixture image")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        let expected = "MACNOTCH CAPTURE TEST"
        (expected as NSString).draw(at: NSPoint(x: 70, y: 130), withAttributes: [
            .font: NSFont.systemFont(ofSize: 76, weight: .bold),
            .foregroundColor: NSColor.black
        ])
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let image = bitmap.cgImage else { fatalError("Could not rasterize the local OCR fixture") }
        let actual = try await LocalTextRecognizer.recognize(in: image)
        precondition(actual.localizedCaseInsensitiveContains(expected), "Local OCR should recognize the known fixture phrase; got: \(actual)")
        print("MacNotch local OCR checks passed")
    }
}
