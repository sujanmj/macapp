import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit

@main
struct MacNotchImagePDFTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchImagePDFTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let first = folder.appendingPathComponent("first.png")
        let second = folder.appendingPathComponent("second.png")
        try writeImage(at: first, color: .systemPink)
        try writeImage(at: second, color: .systemTeal)

        let collision = folder.appendingPathComponent("first-images.pdf")
        try Data("keep existing output".utf8).write(to: collision)
        guard ImagePDFFileActions.destination(for: [first], in: folder)?.lastPathComponent == "first-images-2.pdf" else {
            fatalError("Image PDF output names must avoid overwriting existing files")
        }

        let result = ImagePDFFileActions.makePDF(from: [first, second, first], in: folder)
        guard let output = result.output,
              result.pageCount == 2,
              output.lastPathComponent == "first-images-2.pdf",
              PDFDocument(url: output)?.pageCount == 2,
              FileManager.default.fileExists(atPath: first.path),
              FileManager.default.fileExists(atPath: second.path),
              try Data(contentsOf: collision) == Data("keep existing output".utf8) else {
            fatalError("Image PDF should contain each unique image once and preserve sources and existing files")
        }

        let invalid = folder.appendingPathComponent("missing.png")
        let failure = ImagePDFFileActions.makePDF(from: [first, invalid], in: folder)
        guard failure.output == nil, failure.error != nil,
              !FileManager.default.fileExists(atPath: folder.appendingPathComponent("first-images-3.pdf").path) else {
            fatalError("Unreadable inputs should fail without leaving a partial PDF")
        }
        let empty = ImagePDFFileActions.makePDF(from: [], in: folder)
        guard empty.output == nil, empty.error != nil else { fatalError("An empty selection should be rejected") }

        print("MacNotch image-to-PDF action checks passed")
    }

    private static func writeImage(at url: URL, color: NSColor) throws {
        guard let deviceColor = color.usingColorSpace(.deviceRGB) else { fatalError("Could not convert generated test color") }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        deviceColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let pixelByteCount = 48 * 32 * 4
        var pixels = Data(repeating: 0, count: pixelByteCount)
        pixels.withUnsafeMutableBytes { bytes in
            guard let values = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for index in stride(from: 0, to: pixelByteCount, by: 4) {
                values[index] = UInt8(red * 255)
                values[index + 1] = UInt8(green * 255)
                values[index + 2] = UInt8(blue * 255)
                values[index + 3] = UInt8(alpha * 255)
            }
        }
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(width: 48, height: 32, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 48 * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            fatalError("Could not create generated test image")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("Could not write generated test image") }
    }
}
