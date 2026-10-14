import SwiftUI
import AppKit
import ApplicationServices

func axValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

struct SwitchWindow: Identifiable {
    let id = UUID()
    let app: NSRunningApplication
    let element: AXUIElement
    let title: String
    let minimized: Bool
}

@MainActor
final class WindowSwitcher: ObservableObject {
    @Published var windows: [SwitchWindow] = []
    @Published var selected = 0
    @Published var message = "Enable Accessibility, then hold Option and press Tab to cycle windows. Release Option to switch."
    @Published var ready = false
    var panel: FloatingWindow?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var localMonitor: Any?
    private var workspaceMonitor: NSObjectProtocol?
    private var history: [pid_t] = []
    var visible = false
    private var preparing = false
    private var pendingCommit = false
    private var pendingSteps = 0
    private var requestID = UUID()

    func start() {
        workspaceMonitor = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != getpid() else { return }
            Task { @MainActor in self?.history.removeAll { $0 == app.processIdentifier }; self?.history.insert(app.processIdentifier, at: 0) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.visible else { return event }
            if event.type == .keyDown && event.keyCode == 53 { self.cancel(); return nil }
            return event
        }
        connect(prompt: false)
    }
    func connect(prompt: Bool) {
        guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary) else {
            ready = false; message = "Accessibility is required to list/focus windows. Enable MacSwitch in System Settings, then click Recheck."; return
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: true); ready = true; return }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<WindowSwitcher>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    owner.cancel()
                    if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                return owner.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
            }
        }, userInfo: context)
        guard let tap else {
            ready = false; message = "Keyboard event access is unavailable. Check Accessibility and Input Monitoring, relaunch, then Recheck."; return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        ready = true; message = "Option–Tab ready · Shift reverses · Escape cancels."
    }
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .flagsChanged, visible || preparing, !event.flags.contains(.maskAlternate) { Task { commit() }; return false }
        guard type == .keyDown else { return false }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if (visible || preparing) && code == 53 { cancel(); return true }
        if code == 48, event.flags.contains(.maskAlternate), !event.flags.contains(.maskCommand), !event.flags.contains(.maskControl) {
            cycle(reverse: event.flags.contains(.maskShift)); return true
        }
        if visible && (code == 123 || code == 124) { advance(reverse: code == 123); return true }
        if visible && code == 36 { Task { commit() }; return true }
        return false
    }
    func orderedApps() -> [NSRunningApplication] {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != getpid() }
            .sorted {
                let a = $0.processIdentifier == front ? -1 : (history.firstIndex(of: $0.processIdentifier) ?? 10000)
                let b = $1.processIdentifier == front ? -1 : (history.firstIndex(of: $1.processIdentifier) ?? 10000)
                return a == b ? ($0.localizedName ?? "") < ($1.localizedName ?? "") : a < b
            }
        return apps
    }
    nonisolated static func collect(_ apps: [NSRunningApplication]) -> [SwitchWindow] {
        var result: [SwitchWindow] = []
        for app in apps.prefix(80) {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.08)
            guard let list = axValue(appElement, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            let focused = axValue(appElement, kAXFocusedWindowAttribute)
            let ordered = list.sorted { first, second in
                guard let focused else { return false }
                return CFEqual(first, focused) && !CFEqual(second, focused)
            }
            for window in ordered.prefix(40) {
                AXUIElementSetMessagingTimeout(window, 0.05)
                let role = axValue(window, kAXSubroleAttribute) as? String
                guard role == kAXStandardWindowSubrole || role == kAXDialogSubrole else { continue }
                let title = (axValue(window, kAXTitleAttribute) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                result.append(SwitchWindow(app: app, element: window, title: title?.isEmpty == false ? title! : (app.localizedName ?? "Window"),
                                           minimized: (axValue(window, kAXMinimizedAttribute) as? Bool) ?? false))
            }
        }
        return result
    }
    func cycle(reverse: Bool = false) {
        guard AXIsProcessTrusted() else { connect(prompt: true); return }
        if visible { advance(reverse: reverse); return }
        if preparing { pendingSteps += reverse ? -1 : 1; return }
        preparing = true; pendingCommit = false; pendingSteps = reverse ? -1 : 1
        requestID = UUID()
        let id = requestID
        let apps = orderedApps()
        Task {
            let result = await Task.detached(priority: .userInitiated) { Self.collect(apps) }.value
            guard requestID == id else { return }
            preparing = false; windows = result
            guard !windows.isEmpty else { pendingCommit = false; message = "No accessible standard windows were found."; return }
            selected = ((pendingSteps % windows.count) + windows.count) % windows.count
            visible = true
            if pendingCommit { pendingCommit = false; commit() }
            else { panel?.show(activate: false) }
        }
    }
    func advance(reverse: Bool) {
        guard !windows.isEmpty else { return }
        selected = (selected + (reverse ? -1 : 1) + windows.count) % windows.count
    }
    func cancel() { requestID = UUID(); preparing = false; pendingCommit = false; visible = false; panel?.hide() }
    func commit() {
        if preparing { pendingCommit = true; return }
        guard visible, windows.indices.contains(selected) else { cancel(); return }
        let window = windows[selected]
        cancel()
        guard !window.app.isTerminated else { message = "That app closed; try again."; return }
        if window.minimized { AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
        let appElement = AXUIElementCreateApplication(window.app.processIdentifier)
        window.app.activate(options: [])
        AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window.element)
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        let result = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        if result != .success { message = "The app did not allow that window to be raised. Spaces and some custom windows may restrict focus." }
    }
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let workspaceMonitor { NSWorkspace.shared.notificationCenter.removeObserver(workspaceMonitor) }
    }
}

struct SwitchView: View {
    @ObservedObject var switcher: WindowSwitcher
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Switch windows").font(.headline); Spacer(); Text("⌥ Tab · ⇧ reverse · Esc cancel").font(.caption).foregroundStyle(.secondary) }
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(Array(switcher.windows.enumerated()), id: \.element.id) { index, window in
                            Button {
                                switcher.selected = index; switcher.commit()
                            } label: {
                                VStack(spacing: 10) {
                                    Image(nsImage: window.app.icon ?? NSImage()).resizable().scaledToFit().frame(width: 44, height: 44)
                                    Text(window.title).font(.subheadline.bold()).lineLimit(2).frame(height: 34)
                                    Text((window.app.localizedName ?? "App") + (window.minimized ? " · minimized" : ""))
                                        .font(.caption2).lineLimit(1)
                                }.frame(width: 150, height: 115).padding(10)
                                    .background(index == switcher.selected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(index == switcher.selected ? Color.accentColor : .clear, lineWidth: 2))
                            }.buttonStyle(.plain).id(index)
                        }
                    }.padding(3)
                }.onChange(of: switcher.selected) { _, value in proxy.scrollTo(value, anchor: .center) }
            }
        }.padding(20).frame(minWidth: 520, minHeight: 180)
    }
}

struct SwitchSettings: View {
    @ObservedObject var switcher: WindowSwitcher
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MacSwitch").font(.title2.bold())
            Text(switcher.message)
            Button("Enable Accessibility / Recheck") { switcher.connect(prompt: true) }
            Button("Input Monitoring Settings") { openPrivacy("Privacy_ListenEvent") }
            Divider(); LoginToggle()
            Text("Window titles and app icons stay local. No screenshots are captured. Some windows on other Spaces or with custom accessibility implementations may be unavailable. Quit other Option–Tab switchers to avoid conflicts.").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 460)
    }
}

@MainActor
final class SwitchDelegate: NSObject, NSApplicationDelegate {
    let switcher = WindowSwitcher()
    var setup: FloatingWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        switcher.panel = FloatingWindow(title: "MacSwitch", size: NSSize(width: 780, height: 210), content: SwitchView(switcher: switcher))
        setup = FloatingWindow(title: "MacSwitch Setup", size: NSSize(width: 500, height: 340), content: SwitchSettings(switcher: switcher))
        switcher.start()
        if !switcher.ready { setup?.show() }
    }
    func applicationWillTerminate(_ notification: Notification) { switcher.stop() }
}

@main
struct MacSwitchApp: App {
    @NSApplicationDelegateAdaptor(SwitchDelegate.self) var delegate
    var body: some Scene {
        MenuBarExtra("MacSwitch", systemImage: "rectangle.on.rectangle") {
            Button("Switch Windows") { delegate.switcher.cycle() }
            Button("Setup & Settings") { delegate.setup?.show() }
            Divider(); Button("Quit MacSwitch") { NSApp.terminate(nil) }
        }
        Settings { SwitchSettings(switcher: delegate.switcher) }
    }
}
