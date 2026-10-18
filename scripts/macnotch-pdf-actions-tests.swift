import AppKit
import PDFKit
import Foundation

func require(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
}

func makePDF(at url: URL, pageCount: Int) throws {
    let document = PDFDocument()
    for index in 0..<pageCount {
        let image = NSImage(size: NSSize(width: 120, height: 160))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 120, height: 160)).fill()
        NSString(string: "Page \(index + 1)").draw(at: NSPoint(x: 12, y: 80), withAttributes: [.foregroundColor: NSColor.black])
        image.unlockFocus()
        guard let page = PDFPage(image: image) else { fatalError("Could not make fixture PDF page") }
        document.insert(page, at: document.pageCount)
    }
    require(document.write(to: url), "Could not write fixture PDF")
}

@main
struct PDFFileActionChecks {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchPDFMerge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let first = folder.appendingPathComponent("first.pdf")
        let second = folder.appendingPathComponent("second.pdf")
        let output = folder.appendingPathComponent("merged.pdf")
        try makePDF(at: first, pageCount: 2)
        try makePDF(at: second, pageCount: 1)
        let originalFirst = try Data(contentsOf: first)
        let originalSecond = try Data(contentsOf: second)

        let pages = try PDFFileActions.merge([first, second], to: output)
        require(pages == 3, "Merge should report all pages")
        require(PDFDocument(url: output)?.pageCount == 3, "Output PDF should contain pages in the merged document")
        require(try Data(contentsOf: first) == originalFirst, "First source must remain unchanged")
        require(try Data(contentsOf: second) == originalSecond, "Second source must remain unchanged")

        do {
            _ = try PDFFileActions.merge([first, second], to: first)
            fatalError("Merge must not overwrite an input PDF")
        } catch PDFFileActionError.outputMatchesInput {
            // Expected safety rejection.
        }
        print("MacNotch PDF merge checks passed")
    }
}
