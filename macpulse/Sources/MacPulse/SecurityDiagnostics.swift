import AppKit
import Foundation

enum SecurityStatus: String {
    case enabled = "Enabled"
    case attention = "Review"
    case unavailable = "Unavailable"

    var icon: String {
        switch self {
        case .enabled: return "checkmark.shield.fill"
        case .attention: return "exclamationmark.shield.fill"
        case .unavailable: return "questionmark.shield.fill"
        }
    }
}

struct SecurityFinding: Identifiable {
    let id: String
    let title: String
    let status: SecurityStatus
    let detail: String
    let nextStep: String
}

/// Read-only built-in macOS security-status checks.
/// Not an antivirus scanner, vulnerability audit, or a guarantee of safety.
enum SecurityDiagnostics {
    static func scan() -> [SecurityFinding] {
        [
            readFileVault(),
            readFirewall(),
            readGatekeeper(),
            readSystemIntegrity(),
            readAutomaticUpdates()
        ]
    }

    private static func readFileVault() -> SecurityFinding {
        let output = run("/usr/bin/fdesetup", ["status"])
        if let text = output, text.localizedCaseInsensitiveContains("FileVault is On") {
            return SecurityFinding(id: "filevault", title: "FileVault disk encryption",
                                   status: .enabled, detail: "macOS reports FileVault is on.",
                                   nextStep: "Review encryption and recovery-key settings under Privacy & Security.")
        }
        if let text = output, text.localizedCaseInsensitiveContains("FileVault is Off") {
            return SecurityFinding(id: "filevault", title: "FileVault disk encryption",
                                   status: .attention, detail: "macOS reports FileVault is off.",
                                   nextStep: "Consider enabling FileVault under Privacy & Security after confirming you can safeguard your recovery key.")
        }
        return unavailable("filevault", "FileVault disk encryption",
                           "Could not read FileVault status without elevated privileges.")
    }

    private static func readFirewall() -> SecurityFinding {
        let output = run("/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"])
        if let text = output, text.localizedCaseInsensitiveContains("Firewall is enabled") {
            return SecurityFinding(id: "firewall", title: "Application firewall",
                                   status: .enabled, detail: "The built-in application firewall is enabled.",
                                   nextStep: "Review allowed incoming connections in macOS Network settings.")
        }
        if let text = output, text.localizedCaseInsensitiveContains("Firewall is disabled") {
            return SecurityFinding(id: "firewall", title: "Application firewall",
                                   status: .attention, detail: "The built-in application firewall is disabled.",
                                   nextStep: "Review Network → Firewall and enable it if appropriate for your network exposure.")
        }
        return unavailable("firewall", "Application firewall",
                           "The macOS firewall status tool did not provide a recognizable result.")
    }

    private static func readGatekeeper() -> SecurityFinding {
        let output = run("/usr/sbin/spctl", ["--status"])
        if let text = output, text.localizedCaseInsensitiveContains("assessments enabled") {
            return SecurityFinding(id: "gatekeeper", title: "Gatekeeper assessments",
                                   status: .enabled, detail: "macOS reports app trust assessments are enabled.",
                                   nextStep: "Continue checking downloaded software and avoid blanket quarantine exceptions.")
        }
        if let text = output, text.localizedCaseInsensitiveContains("assessments disabled") {
            return SecurityFinding(id: "gatekeeper", title: "Gatekeeper assessments",
                                   status: .attention, detail: "macOS reports app trust assessments are disabled.",
                                   nextStep: "Review Security settings; avoid disabling protections system-wide.")
        }
        return unavailable("gatekeeper", "Gatekeeper assessments",
                           "This macOS version did not expose a recognized Gatekeeper status.")
    }

    private static func readSystemIntegrity() -> SecurityFinding {
        let output = run("/usr/bin/csrutil", ["status"])
        if let text = output, text.localizedCaseInsensitiveContains("System Integrity Protection status: enabled") {
            return SecurityFinding(id: "sip", title: "System Integrity Protection",
                                   status: .enabled, detail: "macOS reports SIP is enabled.",
                                   nextStep: "SIP protects sensitive system locations from modification.")
        }
        if let text = output, text.localizedCaseInsensitiveContains("System Integrity Protection status: disabled") {
            return SecurityFinding(id: "sip", title: "System Integrity Protection",
                                   status: .attention, detail: "macOS reports SIP is disabled.",
                                   nextStep: "Review why SIP was changed before considering Recovery-mode modifications.")
        }
        return unavailable("sip", "System Integrity Protection",
                           "SIP status was not available from csrutil.")
    }

    private static func readAutomaticUpdates() -> SecurityFinding {
        let output = run("/usr/sbin/softwareupdate", ["--schedule"])
        if let text = output, text.localizedCaseInsensitiveContains("Automatic check is on") {
            return SecurityFinding(id: "updates", title: "Automatic update checks",
                                   status: .enabled, detail: "Automatic software update checks are on.",
                                   nextStep: "This does not guarantee updates are automatically installed; verify the Software Update options.")
        }
        if let text = output, text.localizedCaseInsensitiveContains("Automatic check is off") {
            return SecurityFinding(id: "updates", title: "Automatic update checks",
                                   status: .attention, detail: "Automatic software update checks are off.",
                                   nextStep: "Review macOS Software Update settings.")
        }
        return unavailable("updates", "Automatic update checks",
                           "macOS returned no recognized status; open Software Update to review manually.")
    }

    private static func unavailable(_ id: String, _ name: String, _ note: String) -> SecurityFinding {
        SecurityFinding(id: id, title: name, status: .unavailable,
                        detail: note, nextStep: "Open the matching macOS System Settings pane and review the setting yourself.")
    }

    private static func run(_ executable: String, _ arguments: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let command = Process()
        command.executableURL = URL(fileURLWithPath: executable)
        command.arguments = arguments
        let pipe = Pipe()
        command.standardOutput = pipe
        command.standardError = pipe
        do {
            try command.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            command.waitUntilExit()
            guard command.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func openSettings(for identifier: String) {
        let raw: String
        switch identifier {
        case "firewall":
            raw = "x-apple.systempreferences:com.apple.Network-Settings.extension"
        case "updates":
            raw = "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"
        default:
            raw = "x-apple.systempreferences:com.apple.preference.security"
        }
        if let url = URL(string: raw) {
            NSWorkspace.shared.open(url)
        }
    }
}
