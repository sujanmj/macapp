import CoreGraphics

enum CaptureMarkupRenderer {
    static func render(image: CGImage, strokes: [[CGPoint]]) -> CGImage? {
        guard !strokes.isEmpty,
              let context = CGContext(data: nil, width: image.width, height: image.height,
                                     bitsPerComponent: 8, bytesPerRow: 0,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: bounds)
        context.setStrokeColor(red: 0.15, green: 0.88, blue: 1, alpha: 1)
        context.setLineWidth(max(3, CGFloat(image.width) * 0.004))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes where !stroke.isEmpty {
            context.beginPath()
            context.move(to: pixelPoint(stroke[0], width: image.width, height: image.height))
            for point in stroke.dropFirst() {
                context.addLine(to: pixelPoint(point, width: image.width, height: image.height))
            }
            if stroke.count == 1 {
                let point = pixelPoint(stroke[0], width: image.width, height: image.height)
                context.addLine(to: CGPoint(x: point.x + 0.01, y: point.y + 0.01))
            }
            context.strokePath()
        }
        return context.makeImage()
    }

    private static func pixelPoint(_ point: CGPoint, width: Int, height: Int) -> CGPoint {
        CGPoint(x: point.x * CGFloat(width), y: (1 - point.y) * CGFloat(height))
    }
}
