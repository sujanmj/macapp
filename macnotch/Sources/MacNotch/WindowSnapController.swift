import AppKit
import ApplicationServices
import Combine

enum WindowSnapMode {
    case leftHalf
    case rightHalf
    case maximize
    case center
}

@MainActor
final class WindowSnapController: ObservableObject {
    @Published private(set) var status = ""

    func snap(_ mode: WindowSnapMode) {
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            status = "Allow MacNotch under System Settings → Privacy & Security → Accessibility, then try again."
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            status = "Click the window you want to move, then choose a snap layout."
            return
        }

        let application = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focusedValue) == .success,
              let focusedValue else {
            status = "Could not find a focused window in \(app.localizedName ?? "that app")."
            return
        }
        let window = unsafeBitCast(focusedValue, to: AXUIElement.self)

        guard let currentRect = frame(of: window) else {
            status = "That window does not expose a movable size and position."
            return
        }
        let primary = NSScreen.main ?? NSScreen.screens.first
        let appKitRect = NSRect(x: currentRect.origin.x,
                                y: (primary?.frame.maxY ?? 0) - currentRect.maxY,
                                width: currentRect.width,
                                height: currentRect.height)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(appKitRect) }) ?? primary
        guard let visible = screen?.visibleFrame else {
            status = "Could not determine the window's screen."
            return
        }

        let target: NSRect
        switch mode {
        case .leftHalf:
            target = NSRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .rightHalf:
            target = NSRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .maximize:
            target = visible
        case .center:
            let width = min(visible.width * 0.72, max(600, currentRect.width))
            let height = min(visible.height * 0.82, max(420, currentRect.height))
            target = NSRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
        }

        var axSize = CGSize(width: target.width, height: target.height)
        let sizeValue = AXValueCreate(.cgSize, &axSize)!
        let axTop = (primary?.frame.maxY ?? 0) - target.maxY
        var axOrigin = CGPoint(x: target.minX, y: axTop)
        let pointValue = AXValueCreate(.cgPoint, &axOrigin)!
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
        guard sizeResult == .success, positionResult == .success else {
            status = "macOS or this app did not allow that window to move."
            return
        }
        status = "Moved \(app.localizedName ?? "window") to \(label(for: mode))."
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(positionValue, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    private func label(for mode: WindowSnapMode) -> String {
        switch mode {
        case .leftHalf: "left half"
        case .rightHalf: "right half"
        case .maximize: "full screen area"
        case .center: "centered"
        }
    }
}
