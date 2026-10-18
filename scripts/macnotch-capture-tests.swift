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

        guard let marked = CaptureMarkupRenderer.render(image: image, strokes: [[
            CGPoint(x: 0.10, y: 0.10), CGPoint(x: 0.30, y: 0.10), CGPoint(x: 0.40, y: 0.16)
        ]]), let data = marked.dataProvider?.data else {
            fatalError("Markup renderer should return a bitmap with pixels")
        }
        precondition(marked.width == width && marked.height == height, "Markup must preserve screenshot dimensions")
        let bytes = data as Data
        let hasCyanMarkup = stride(from: 0, to: max(0, bytes.count - 3), by: 4).contains { index in
            let a = bytes[index], g = bytes[index + 1], c = bytes[index + 2]
            return g > 160 && ((a < 100 && c > 170) || (c < 100 && a > 170))
        }
        precondition(hasCyanMarkup, "Marked image should contain the rendered cyan stroke")
        let markedText = try await LocalTextRecognizer.recognize(in: marked)
        precondition(markedText.localizedCaseInsensitiveContains(expected), "Markup should preserve readable source text; got: \(markedText)")
        print("MacNotch local OCR checks passed")
    }
}
