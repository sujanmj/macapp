import Foundation
import PDFKit

enum PDFFileActionError: LocalizedError {
    case needsMultipleFiles
    case unreadable(URL)
    case outputMatchesInput
    case couldNotWrite

    var errorDescription: String? {
        switch self {
        case .needsMultipleFiles: "Choose at least two PDF files to merge."
        case .unreadable(let url): "Could not read \(url.lastPathComponent) as a PDF."
        case .outputMatchesInput: "Choose a new output file; source PDFs are never overwritten."
        case .couldNotWrite: "The merged PDF could not be saved. Check folder permissions and free space."
        }
    }
}

enum PDFFileActions {
    /// Joins PDF pages in source order and writes a separate PDF without modifying inputs.
    @discardableResult
    static func merge(_ sources: [URL], to destination: URL) throws -> Int {
        guard sources.count >= 2 else { throw PDFFileActionError.needsMultipleFiles }
        let outputPath = destination.standardizedFileURL.resolvingSymlinksInPath().path
        guard !sources.contains(where: { $0.standardizedFileURL.resolvingSymlinksInPath().path == outputPath }) else {
            throw PDFFileActionError.outputMatchesInput
        }

        let merged = PDFDocument()
        var pageIndex = 0
        for source in sources {
            guard let document = PDFDocument(url: source), document.pageCount > 0 else {
                throw PDFFileActionError.unreadable(source)
            }
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { throw PDFFileActionError.unreadable(source) }
                merged.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }
        guard merged.write(to: destination) else { throw PDFFileActionError.couldNotWrite }
        return pageIndex
    }
}
