import AppKit
import ScreenCaptureKit

@MainActor
final class LumaFlowController: NSObject, NSApplicationDelegate {
    private let brightness = BuiltInBrightness()
    private let sampler = ScreenLuminance()
    private var item: NSStatusItem!
    private var enabled = false
    private var baseline: Float = 0.65
    private var lastTarget: Float?
    private var lastWrite: Date = .distantPast
    private var lastMean: Double = 0.5
    private var timer: Timer?
    private var pausedUntil: Date = .distantPast
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)
        LaunchAtLogin.configureOnLaunch()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "LumaFlow")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "LumaFlow · content-aware brightness"
        baseline = brightness.read() ?? 0.65
        sampler.onSample = { [weak self] value in self?.process(value) }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        updateMenu()
    }

    private func process(_ mean: Double) {
        guard enabled, Date() >= pausedUntil else { return }
        lastMean = 0.65 * lastMean + 0.35 * mean
        // Brighter content receives lower backlight; darker content gets a boost.
        // Preserve the user's chosen baseline and clamp changes to ±0.20.
        let bias = Float((0.48 - lastMean) * 0.38)
        let target = min(1, max(0.20, baseline + bias))
        guard Date().timeIntervalSince(lastWrite) >= 0.75 else { return }
        guard let current = brightness.read() else { return }
        if let lastTarget, abs(current - lastTarget) > 0.08 {
            // The user may have changed brightness with the keyboard: suspend briefly.
            baseline = current
            self.lastTarget = nil
            pausedUntil = Date().addingTimeInterval(20)
            return
        }
        let next = current + min(0.018, max(-0.018, target - current))
        if abs(next - current) > 0.002, brightness.write(next) {
            lastWrite = Date()
            lastTarget = next
        }
    }

    private func tick() {
        guard enabled else { return }
        // If the user changes the hardware brightness, adopt it as a new baseline.
        if let lastTarget, let observed = brightness.read(), abs(observed - lastTarget) > 0.08 {
            baseline = observed
            self.lastTarget = nil
            pausedUntil = Date().addingTimeInterval(20)
        }
    }

    @objc private func toggle() {
        if enabled {
            enabled = false
            sampler.stop()
            lastTarget = nil
            // Restore user's original baseline when the automation is disabled.
            _ = brightness.write(baseline)
            updateMenu()
            return
        }
        guard brightness.isAvailable else {
            showAlert("Built-in brightness control unavailable", "LumaFlow currently supports only built-in displays where macOS exposes the DisplayServices brightness interface.")
            return
        }
        baseline = brightness.read() ?? baseline
        enabled = true
        updateMenu()
        Task {
            do { try await sampler.start() }
            catch {
                enabled = false
                updateMenu()
                showAlert("Screen Recording permission required", "Allow LumaFlow under System Settings → Privacy & Security → Screen & System Audio Recording, then enable it again. \n\nDetails: \(error.localizedDescription)")
            }
        }
    }

    @objc private func setBaseline(_ sender: NSMenuItem) {
        baseline = Float(sender.tag) / 100
        _ = brightness.write(baseline)
        lastTarget = baseline
        pausedUntil = Date().addingTimeInterval(3)
        updateMenu()
    }

    @objc private func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        if let error = LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled) {
            showAlert("Launch at Login", error)
        }
        updateMenu()
    }

    @objc private func openLoginItemsSettings() {
        LaunchAtLogin.openSettings()
    }

    @objc private func checkForUpdates() {
        Task { await GitHubReleaseUpdater.check(appName: "LumaFlow", releasePrefix: "lumaflow-v") }
    }

    @objc private func quit() {
        enabled = false
        sampler.stop()
        NSApp.terminate(nil)
    }

    private func showAlert(_ title: String, _ details: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = details
        alert.runModal()
    }

    private func updateMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: "LumaFlow · Local screen analysis", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let toggleItem = NSMenuItem(title: enabled ? "Disable Auto Brightness" : "Enable Auto Brightness", action: #selector(toggle), keyEquivalent: "b")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        let label = NSMenuItem(title: "Your baseline brightness", action: nil, keyEquivalent: "")
        label.isEnabled = false
        menu.addItem(label)
        for value in [25, 40, 55, 70, 85, 100] {
            let entry = NSMenuItem(title: "\(value)%", action: #selector(setBaseline(_:)), keyEquivalent: "")
            entry.tag = value
            entry.target = self
            entry.state = abs(baseline - Float(value) / 100) < 0.07 ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        let permission = NSMenuItem(title: "Screen Recording Settings…", action: #selector(openPrivacy), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        if LaunchAtLogin.requiresApproval {
            let settings = NSMenuItem(title: "Approve Login Item in Settings…", action: #selector(openLoginItemsSettings), keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
        }
        let updater = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updater.target = self
        menu.addItem(updater)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit LumaFlow", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
    }
}

@main
enum LumaFlowEntry {
    static func main() {
        let app = NSApplication.shared
        let delegate = LumaFlowController()
        app.delegate = delegate
        app.run()
    }
}
