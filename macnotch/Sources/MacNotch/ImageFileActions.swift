import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct BatchImageExportOutcome: Equatable {
    let outputs: [URL]
    let failures: [String]
}

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

    static func createSmallerJPEGs(from sourceURLs: [URL], in directory: URL, quality: CGFloat = 0.76, maxPixelSize: Int = 2048) throws -> BatchImageExportOutcome {
        guard directory.isFileURL,
              (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            throw ImageFileActionError.invalidDirectory
        }

        let uniqueSources = sourceURLs.reduce(into: [URL]()) { result, url in
            let standardized = url.standardizedFileURL
            if standardized.isFileURL, !result.contains(where: { $0.standardizedFileURL == standardized }) {
                result.append(standardized)
            }
        }
        var reservedNames = Set<String>()
        var outputs: [URL] = []
        var failures: [String] = []
        for source in uniqueSources {
            guard FileManager.default.fileExists(atPath: source.path) else {
                failures.append("\(source.lastPathComponent): file is missing")
                continue
            }
            guard let imageType = UTType(filenameExtension: source.pathExtension), imageType.conforms(to: .image) else {
                failures.append("\(source.lastPathComponent): not a supported image")
                continue
            }
            let destination = uniqueDestination(for: source, in: directory, reservedNames: &reservedNames)
            do {
                try createSmallerJPEG(from: source, to: destination, quality: quality, maxPixelSize: maxPixelSize)
                outputs.append(destination)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                failures.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return BatchImageExportOutcome(outputs: outputs, failures: failures)
    }

    private static func uniqueDestination(for source: URL, in directory: URL, reservedNames: inout Set<String>) -> URL {
        let base = source.deletingPathExtension().lastPathComponent + "-smaller"
        var index = 1
        while true {
            let suffix = index == 1 ? "" : " \(index)"
            let name = base + suffix + ".jpg"
            let foldedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let destination = directory.appendingPathComponent(name)
            if !reservedNames.contains(foldedName), !FileManager.default.fileExists(atPath: destination.path) {
                reservedNames.insert(foldedName)
                return destination
            }
            index += 1
        }
    }
}

private enum ImageFileActionError: LocalizedError {
    case invalidDestination
    case unreadableImage
    case imageProcessingFailed
    case writeFailed
    case invalidDirectory

    var errorDescription: String? {
        switch self {
        case .invalidDestination: "Choose a new file name; the original image will not be overwritten."
        case .unreadableImage: "MacNotch could not read this image file."
        case .imageProcessingFailed: "MacNotch could not prepare a smaller JPEG copy."
        case .writeFailed: "The JPEG copy could not be written. Check the destination and available disk space."
        case .invalidDirectory: "Choose an existing folder to save the image copies."
        }
    }
}
