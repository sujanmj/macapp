import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageFileActions {
    static func createSmallerJPEG(from sourceURL: URL, to destinationURL: URL, quality: CGFloat = 0.76, maxPixelSize: Int = 2048) throws {
        guard sourceURL.isFileURL, destinationURL.isFileURL,
              sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else {
            throw ImageFileActionError.invalidDestination
        }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { throw ImageFileActionError.unreadableImage }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize)
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: thumbnail.width, height: thumbnail.height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ImageFileActionError.imageProcessingFailed
        }

        // JPEG has no alpha channel, so transparent pixels are composited onto white.
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height))
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height))
        guard let flattened = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageFileActionError.imageProcessingFailed
        }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        properties.removeValue(forKey: kCGImagePropertyOrientation)
        properties[kCGImageDestinationLossyCompressionQuality] = min(1, max(0.1, quality))
        CGImageDestinationAddImage(destination, flattened, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw ImageFileActionError.writeFailed
        }
    }
}

private enum ImageFileActionError: LocalizedError {
    case invalidDestination
    case unreadableImage
    case imageProcessingFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidDestination: "Choose a new file name; the original image will not be overwritten."
        case .unreadableImage: "MacNotch could not read this image file."
        case .imageProcessingFailed: "MacNotch could not prepare a smaller JPEG copy."
        case .writeFailed: "The JPEG copy could not be written. Check the destination and available disk space."
        }
    }
}
