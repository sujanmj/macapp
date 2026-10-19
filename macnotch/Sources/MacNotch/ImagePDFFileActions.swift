import AppKit
import Foundation
import PDFKit

struct ImagePDFResult {
    let output: URL?
    let pageCount: Int
    let error: Error?
}

enum ImagePDFFileActions {
    static func destination(for sources: [URL], in folder: URL, fileManager: FileManager = .default) -> URL? {
        guard let first = sources.first else { return nil }
        let stem = first.deletingPathExtension().lastPathComponent + "-images"
        var suffix = 1
        while true {
            let discriminator = suffix == 1 ? "" : "-\(suffix)"
            let candidate = folder.appendingPathComponent("\(stem)\(discriminator).pdf")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
    }

    static func makePDF(from sources: [URL], in folder: URL, fileManager: FileManager = .default) -> ImagePDFResult {
        let uniqueSources = sources.map(\.standardizedFileURL).reduce(into: [URL]()) { result, source in
            if !result.contains(source) { result.append(source) }
        }
        guard !uniqueSources.isEmpty, let destination = destination(for: uniqueSources, in: folder, fileManager: fileManager) else {
            return ImagePDFResult(output: nil, pageCount: 0, error: ImagePDFActionError.noImages)
        }

        let document = PDFDocument()
        for source in uniqueSources {
            guard fileManager.fileExists(atPath: source.path),
                  let image = NSImage(contentsOf: source),
                  let page = PDFPage(image: image) else {
                return ImagePDFResult(output: nil, pageCount: 0, error: ImagePDFActionError.unreadable(source))
            }
            document.insert(page, at: document.pageCount)
        }
        guard document.pageCount == uniqueSources.count, document.write(to: destination) else {
            try? fileManager.removeItem(at: destination)
            return ImagePDFResult(output: nil, pageCount: 0, error: ImagePDFActionError.writeFailed)
        }
        return ImagePDFResult(output: destination, pageCount: document.pageCount, error: nil)
    }
}

private enum ImagePDFActionError: LocalizedError {
    case noImages
    case unreadable(URL)
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noImages: "Add images to the tray before creating a PDF."
        case .unreadable(let url): "Could not read \(url.lastPathComponent) as an image."
        case .writeFailed: "The image PDF could not be saved. Check folder permissions and free space."
        }
    }
}
