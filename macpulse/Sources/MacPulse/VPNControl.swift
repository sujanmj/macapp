import AppKit
import Foundation

struct VPNService: Identifiable {
    let name: String
    let status: String
    var id: String { name }
    var connected: Bool { status.lowercased() == "connected" }
}

/// Manages *existing* macOS VPN services. It does not provision a VPN server,
/// intercept traffic, or claim encryption unless the system reports connected.
enum VPNControl {
    static func list() -> [VPNService] {
        guard let text = try? execute(["--nc", "list"]) else { return [] }
        let regex = try! NSRegularExpression(pattern: #"((Connected|Disconnected|Connecting|Disconnecting))s+"([^"]+)""#)
        return text.components(separatedBy: .newlines).compactMap { line in
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let hit = regex.firstMatch(in: line, range: range), hit.numberOfRanges >= 3 else { return nil }
            return VPNService(name: ns.substring(with: hit.range(at: 2)),
                              status: ns.substring(with: hit.range(at: 1)))
        }
    }

    static func toggle(_ service: VPNService) throws {
        let operation = service.connected ? "stop" : "start"
        _ = try execute(["--nc", operation, service.name])
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }


    /// Optional integration with the official, independently installed
    /// Cloudflare WARP client. MacPulse does not bundle WARP or its tunnel.
    static var warpCLI: URL? {
        let locations = [
            "/opt/homebrew/bin/warp-cli",
            "/usr/local/bin/warp-cli",
            "/usr/bin/warp-cli"
        ]
        return locations.compactMap { path -> URL? in
            FileManager.default.isExecutableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
        }.first
    }

    static func warpStatus() -> String? {
        guard let cli = warpCLI else { return nil }
        return try? run(executable: cli, arguments: ["status"])
    }

    static func warpConnected(_ status: String) -> Bool {
        let lower = status.lowercased()
        // Check disconnected first, since the substring "connected" also
        // occurs in "disconnected".
        if lower.contains("disconnected") || lower.contains("disconnecting") { return false }
        return lower.contains("connected")
    }

    static func toggleWARP(connected: Bool) throws {
        guard let cli = warpCLI else {
            throw NSError(domain: "MacPulseWARP", code: 1, userInfo:
                [NSLocalizedDescriptionKey: "Install the official Cloudflare WARP macOS client first."])
        }
        _ = try run(executable: cli, arguments: [connected ? "disconnect" : "connect"])
    }

    private static func run(executable: URL, arguments: [String]) throws -> String {
        let p = Process()
        p.executableURL = executable
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let response = String(data: data, encoding: .utf8) ?? ""
        guard p.terminationStatus == 0 else {
            throw NSError(domain: "MacPulseWARP", code: Int(p.terminationStatus), userInfo:
                [NSLocalizedDescriptionKey: response.isEmpty ? "WARP client returned an error." : response])
        }
        return response
    }
    private static func execute(_ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        task.arguments = arguments
        let output = Pipe()
        task.standardOutput = output
        task.standardError = output
        try task.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "MacPulseVPN", code: Int(task.terminationStatus), userInfo:
                [NSLocalizedDescriptionKey: text.isEmpty ? "VPN command failed." : text])
        }
        return text
    }
}
