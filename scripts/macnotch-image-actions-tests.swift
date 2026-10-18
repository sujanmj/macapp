import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct MacNotchImageActionTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchImageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("original.png")
        let output = folder.appendingPathComponent("smaller.jpg")

        let width = 3000
        let height = 1500
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let source = CGImageDestinationCreateWithURL(original as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            fatalError("Could not create the generated PNG fixture")
        }
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { fatalError("Could not render the generated PNG fixture") }
        CGImageDestinationAddImage(source, image, nil)
        guard CGImageDestinationFinalize(source) else { fatalError("Could not save generated PNG fixture") }

        try ImageFileActions.createSmallerJPEG(from: original, to: output, maxPixelSize: 2048)
        guard let originalSource = CGImageSourceCreateWithURL(original as CFURL, nil),
              let outputSource = CGImageSourceCreateWithURL(output as CFURL, nil),
              let originalProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) as? [CFString: Any],
              let outputProperties = CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [CFString: Any],
              (originalProperties[kCGImagePropertyPixelWidth] as? Int) == width,
              (originalProperties[kCGImagePropertyPixelHeight] as? Int) == height,
              (outputProperties[kCGImagePropertyPixelWidth] as? Int) == 2048,
              (outputProperties[kCGImagePropertyPixelHeight] as? Int) == 1024,
              CGImageSourceGetType(outputSource) == UTType.jpeg.identifier as CFString,
              FileManager.default.fileExists(atPath: original.path) else {
            fatalError("Image conversion dimensions, format, or original-file safety failed")
        }

        var rejectedOriginalDestination = false
        do { try ImageFileActions.createSmallerJPEG(from: original, to: original) }
        catch { rejectedOriginalDestination = true }
        guard rejectedOriginalDestination else { fatalError("The original image destination should have been rejected") }

        print("MacNotch image action checks passed")
    }
}
