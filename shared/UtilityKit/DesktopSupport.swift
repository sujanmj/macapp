import SwiftUI
import AppKit
import Carbon
import ServiceManagement

/// Carbon hotkeys do not inspect unrelated keystrokes or require a key logger.
final class GlobalShortcut {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    private let hotkeyID = UInt32.random(in: 1...UInt32.max)
    @discardableResult
    func register(key: UInt32, modifiers: UInt32) -> Bool {
        unregister()
        var kind = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            var received = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &received) == noErr,
                  received.id == owner.hotkeyID else { return OSStatus(eventNotHandledErr) }
            owner.action?()
            return noErr
        }, 1, &kind, context, &handler)
        guard installed == noErr else { return false }
        let id = EventHotKeyID(signature: OSType(0x4D414350), id: hotkeyID)
        let status = RegisterEventHotKey(key, modifiers, id, GetApplicationEventTarget(), 0, &reference)
        if status != noErr { unregister() }
        return status == noErr
    }
    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
        reference = nil; handler = nil
    }
    deinit { unregister() }
}

final class UtilityPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingWindow {
    let panel: UtilityPanel
    init<Content: View>(title: String, size: NSSize, content: Content, nonactivating: Bool = true) {
        panel = UtilityPanel(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.titled, .closable, .resizable, nonactivating ? .nonactivatingPanel : .utilityWindow],
                             backing: .buffered, defer: false)
        panel.title = title
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.contentView = NSHostingView(rootView: content)
        panel.center()
    }
    func show(activate: Bool = true) {
        if activate { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) }
        else { panel.orderFrontRegardless() }
    }
    func show(near pointer: CGPoint) {
        guard pointer.x.isFinite, pointer.y.isFinite else { show(activate: false); return }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        let bounds = (screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame).insetBy(dx: 8, dy: 8)
        var origin = CGPoint(x: pointer.x - panel.frame.width * 0.45, y: pointer.y - panel.frame.height * 0.45)
        origin.x = min(max(origin.x, bounds.minX), max(bounds.minX, bounds.maxX - panel.frame.width))
        origin.y = min(max(origin.y, bounds.minY), max(bounds.minY, bounds.maxY - panel.frame.height))
        panel.setFrameOrigin(origin)
        show(activate: false)
    }
    func hide() { panel.orderOut(nil) }
}

struct LoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Open at login", isOn: Binding(get: { enabled }, set: { value in
                do {
                    if value { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                    enabled = SMAppService.mainApp.status == .enabled
                    message = SMAppService.mainApp.status == .requiresApproval ? "Approve this app in Login Items Settings." : ""
                } catch { message = error.localizedDescription }
            }))
            if !message.isEmpty { Text(message).font(.caption) }
            Button("Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
        }
    }
}

func openPrivacy(_ section: String) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?" + section)!)
}

func copyText(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
