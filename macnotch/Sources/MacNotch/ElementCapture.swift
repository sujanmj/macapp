import AppKit
import ScreenCaptureKit

@MainActor
final class ElementCaptureController: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var message = "Capture a screenshot and extract visible text on this Mac."
    @Published private(set) var image: NSImage?
    @Published private(set) var recognizedText = ""
    @Published private(set) var latestCapture: URL?

    func captureScreen() async {
        guard !busy else { return }
        busy = true
        message = "Capturing the primary display…"
        recognizedText = ""
        defer { busy = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mainDisplayID = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
                throw CaptureError.noDisplay
            }
            let excludedApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.showsCursor = true

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            let url = try save(cgImage)
            image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            latestCapture = url
            message = "Screenshot saved to Pictures/MacNotch Captures. Reading visible text…"

            recognizedText = try await LocalTextRecognizer.recognize(in: cgImage)
            message = recognizedText.isEmpty ? "Screenshot saved. No readable text was detected." : "Screenshot saved. Text recognition runs locally on this Mac."
        } catch {
            message = "Capture failed. Allow MacNotch in System Settings → Privacy & Security → Screen Recording, then try again. (\(error.localizedDescription))"
        }
    }

    func copyText() {
        guard !recognizedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedText, forType: .string)
        message = "Recognized text copied to the clipboard."
    }

    func showLatest() {
        guard let latestCapture else { return }
        NSWorkspace.shared.activateFileViewerSelecting([latestCapture])
    }

    private func save(_ image: CGImage) throws -> URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/MacNotch Captures", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = folder.appendingPathComponent("MacNotch-\(formatter.string(from: Date())).png")
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CaptureError.pngEncoding
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}

private enum CaptureError: LocalizedError {
    case noDisplay
    case pngEncoding

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display is available to capture."
        case .pngEncoding: "The screenshot could not be encoded as a PNG."
        }
    }
}
