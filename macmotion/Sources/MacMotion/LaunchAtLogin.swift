import AppKit
import ServiceManagement

/// Keep the system login-item status authoritative. A registered item may still
/// require the user to approve it in System Settings.
@MainActor
enum LaunchAtLogin {
    private static let preferenceKey = "MacApp.launchAtLoginDesired"
    private static var service: SMAppService { .mainApp }

    static var isEnabled: Bool { service.status == .enabled }
    static var requiresApproval: Bool { service.status == .requiresApproval }

    static var menuTitle: String {
        switch service.status {
        case .enabled: return "Launch at Login"
        case .requiresApproval: return "Enable Launch at Login in Settings…"
        case .notRegistered: return "Launch at Login"
        case .notFound: return "Open Login Items Settings…"
        @unknown default: return "Open Login Items Settings…"
        }
    }

    static func configureOnLaunch() {
        let settings = UserDefaults.standard
        if settings.object(forKey: preferenceKey) == nil {
            settings.set(true, forKey: preferenceKey)
        }
        guard settings.bool(forKey: preferenceKey), isInstalledInApplications else { return }
        switch service.status {
        case .enabled, .requiresApproval:
            // Avoid duplicate registration when macOS already has the login item.
            break
        case .notRegistered:
            do { try service.register() }
            catch { NSLog("Launch at Login: %@", error.localizedDescription) }
        case .notFound:
            // Can't register until macOS can find the installed app.
            break
        @unknown default:
            break
        }
    }

    private static var isInstalledInApplications: Bool {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        let path = bundleURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").standardizedFileURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(home + "/")
    }

    /// Returns a message on failure or when macOS authorization is required.
    /// Tapping Enable again never re-registers a pending login item.
    static func setEnabled(_ desired: Bool) -> String? {
        guard isInstalledInApplications else {
            return "Install this app into Applications first. Login Items can't be enabled from a mounted DMG or Xcode build."
        }

        let status = service.status
        if desired {
            switch status {
            case .enabled:
                UserDefaults.standard.set(true, forKey: preferenceKey)
                return nil
            case .requiresApproval:
                UserDefaults.standard.set(true, forKey: preferenceKey)
                openSettings()
                return "The login item already exists, but macOS needs your approval. Enable this app in Login Items & Extensions."
            case .notRegistered:
                do { try service.register() }
                catch {
                    // A stale or duplicate system record may cause register() to
                    // fail even when the item already exists. Let macOS resolve it.
                    openSettings()
                    return "macOS couldn't register the login item: \(error.localizedDescription)\nOpen Login Items & Extensions to enable the existing entry, or remove a stale duplicate."
                }
                UserDefaults.standard.set(true, forKey: preferenceKey)
                if service.status == .requiresApproval {
                    openSettings()
                    return "Registration succeeded, but macOS requires approval in Login Items & Extensions."
                }
                return nil
            case .notFound:
                openSettings()
                return "macOS cannot find this app's login service. Check the installed app under Login Items & Extensions."
            @unknown default:
                openSettings()
                return "macOS could not determine the login-item state."
            }
        }

        switch status {
        case .enabled, .requiresApproval:
            do { try service.unregister() }
            catch {
                openSettings()
                return "macOS couldn't disable the login item: \(error.localizedDescription)"
            }
        case .notRegistered, .notFound:
            break
        @unknown default:
            break
        }
        UserDefaults.standard.set(false, forKey: preferenceKey)
        return nil
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
