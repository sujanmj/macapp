import AppKit
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    private static let preferenceKey = "MacApp.launchAtLoginDesired"
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func configureOnLaunch() {
        let prefs = UserDefaults.standard
        if prefs.object(forKey: preferenceKey) == nil {
            prefs.set(true, forKey: preferenceKey)
        }
        guard prefs.bool(forKey: preferenceKey),
              SMAppService.mainApp.status == .notRegistered,
              isInstalledInApplications else { return }
        do { try SMAppService.mainApp.register() }
        catch { NSLog("Login registration failed: %@", error.localizedDescription) }
    }

    private static var isInstalledInApplications: Bool {
        let app = Bundle.main.bundleURL.standardizedFileURL.path
        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").standardizedFileURL.path
        return app.hasPrefix("/Applications/") || app.hasPrefix(homeApps + "/")
    }

    static func setEnabled(_ enabled: Bool) -> String? {
        guard isInstalledInApplications else {
            return "Install the app in Applications first. Login registration is unavailable from a mounted DMG or Xcode build."
        }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: preferenceKey)
            if enabled && SMAppService.mainApp.status == .requiresApproval {
                return "Approve the app under System Settings → General → Login Items & Extensions."
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
