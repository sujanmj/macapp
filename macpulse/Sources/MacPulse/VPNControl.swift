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
