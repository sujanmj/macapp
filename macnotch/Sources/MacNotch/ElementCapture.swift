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
    @Published private(set) var selection: CGRect?
    @Published private(set) var annotations: [[CGPoint]] = []
    private var capturedImage: CGImage?

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
            capturedImage = cgImage
            selection = nil
            annotations = []
            image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            latestCapture = url
            message = "Screenshot saved to Pictures/MacNotch Captures. Reading visible text…"

            recognizedText = try await LocalTextRecognizer.recognize(in: cgImage)
            message = recognizedText.isEmpty ? "Screenshot saved. No readable text was detected." : "Screenshot saved. Text recognition runs locally on this Mac."
        } catch {
            message = "Capture failed. Allow MacNotch in System Settings → Privacy & Security → Screen Recording, then try again. (\(error.localizedDescription))"
        }
    }

    func setSelection(_ rect: CGRect?) { selection = rect }

    func readSelection() async {
        guard let capturedImage, let selection,
              selection.width > 0.015, selection.height > 0.015 else {
            message = "Drag across an area of the screenshot first."
            return
        }
        let bounds = CGRect(x: 0, y: 0, width: capturedImage.width, height: capturedImage.height)
        let pixelRect = CGRect(x: selection.minX * bounds.width, y: selection.minY * bounds.height,
                               width: selection.width * bounds.width, height: selection.height * bounds.height)
            .integral.intersection(bounds)
        guard let cropped = capturedImage.cropping(to: pixelRect), cropped.width > 1, cropped.height > 1 else {
            message = "Could not crop that area. Drag a larger selection and try again."
            return
        }
        busy = true
        message = "Saving the selected area and reading its text…"
        defer { busy = false }
        do {
            let url = try save(cropped, prefix: "MacNotch-Selection")
            self.capturedImage = cropped
            annotations = []
            image = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
            self.selection = nil
            latestCapture = url
            recognizedText = try await LocalTextRecognizer.recognize(in: cropped)
            message = recognizedText.isEmpty ? "Selection saved. No readable text was detected." : "Selection saved. Text recognition runs locally on this Mac."
        } catch {
            message = "Could not read this selection: \(error.localizedDescription)"
        }
    }

    func addAnnotation(_ points: [CGPoint]) {
        guard points.count > 1 else { return }
        annotations.append(points)
    }

    func undoAnnotation() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
    }

    func saveAnnotatedCapture() {
        guard let capturedImage, let markedImage = CaptureMarkupRenderer.render(image: capturedImage, strokes: annotations) else {
            message = "Draw on the screenshot before saving a marked copy."
            return
        }
        do {
            let url = try save(markedImage, prefix: "MacNotch-Marked")
            self.capturedImage = markedImage
            image = NSImage(cgImage: markedImage, size: NSSize(width: markedImage.width, height: markedImage.height))
            latestCapture = url
            annotations = []
            selection = nil
            message = "Marked screenshot saved to Pictures/MacNotch Captures."
        } catch {
            message = "Could not save the marked screenshot: \(error.localizedDescription)"
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

    private func save(_ image: CGImage, prefix: String = "MacNotch") throws -> URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/MacNotch Captures", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = folder.appendingPathComponent("\(prefix)-\(formatter.string(from: Date())).png")
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
