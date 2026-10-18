import AppKit
import ScreenCaptureKit

struct CaptureWindowOption: Identifiable, Hashable {
    let id: CGWindowID
    let title: String
    let appName: String
}

enum CaptureTarget: Hashable {
    case display
    case window(CGWindowID)
}

@MainActor
final class ElementCaptureController: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var message = "Capture a screenshot and extract visible text on this Mac."
    @Published private(set) var image: NSImage?
    @Published private(set) var recognizedText = ""
    @Published private(set) var latestCapture: URL?
    @Published private(set) var windows: [CaptureWindowOption] = []
    @Published var target: CaptureTarget = .display

    func refreshWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            windows = content.windows.compactMap { window in
                guard window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier,
                      let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                      window.frame.width >= 200, window.frame.height >= 120 else { return nil }
                return CaptureWindowOption(id: window.windowID, title: title,
                                           appName: window.owningApplication?.applicationName ?? "App")
            }.sorted { lhs, rhs in
                lhs.appName == rhs.appName ? lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                                           : lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }
            if case .window(let id) = target, !windows.contains(where: { $0.id == id }) { target = .display }
        } catch {
            windows = []
        }
    }

    func captureScreen() async {
        guard !busy else { return }
        busy = true
        message = "Capturing the primary display…"
        recognizedText = ""
        defer { busy = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let filter: SCContentFilter
            switch target {
            case .display:
                let mainDisplayID = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
                    throw CaptureError.noDisplay
                }
                let excludedApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
                filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
            case .window(let windowID):
                guard let window = content.windows.first(where: { $0.windowID == windowID }),
                      window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
                    await refreshWindows()
                    throw CaptureError.windowUnavailable
                }
                filter = SCContentFilter(desktopIndependentWindow: window)
            }
            let configuration = SCStreamConfiguration()
            let scale = CGFloat(filter.pointPixelScale)
            configuration.width = max(1, Int(filter.contentRect.width * scale))
            configuration.height = max(1, Int(filter.contentRect.height * scale))
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
    case windowUnavailable
    case pngEncoding

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display is available to capture."
        case .windowUnavailable: "That window is no longer available. Refresh the list and try again."
        case .pngEncoding: "The screenshot could not be encoded as a PNG."
        }
    }
}
