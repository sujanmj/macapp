import Foundation
import CryptoKit
import Darwin

/// Runs after the menu-bar app quits; copies only a SHA-256 verified GitHub release.
/// Never removes Gatekeeper quarantine or elevates privileges.
@main
struct MacAppInstallHelper {
    static func main() {
        let args = CommandLine.arguments
        guard args.count == 7, let pid = Int32(args[1]), pid > 1 else { return }
        let dmg = URL(fileURLWithPath: args[2])
        let name = args[3]
        let id = args[4]
        let version = args[5]
        let hash = args[6].lowercased()
        guard (name == "MacMotion" && id == "com.macmotion.wallpaper") ||
              (name == "LumaFlow" && id == "com.sujanmj.lumaflow") ||
              (name == "MacPulse" && id == "com.sujanmj.macpulse"),
              version.range(of: #"^[0-9]+(\.[0-9]+){1,3}$"#, options: .regularExpression) != nil,
              hash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else { return }

        // Wait for the current app to exit before replacing its bundle.
        for _ in 0..<120 {
            if kill(pid, 0) != 0 { break }
            usleep(250_000)
        }
        guard kill(pid, 0) != 0 else { return }

        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("macapp-install-\(UUID().uuidString)")
        let mount = directory.appendingPathComponent("volume")
        var attached = false
        do {
            try fm.createDirectory(at: mount, withIntermediateDirectories: true)
            defer {
                if attached { try? run("/usr/bin/hdiutil", ["detach", mount.path]) }
                try? fm.removeItem(at: directory)
            }
            guard try digest(dmg) == hash else {
                throw InstallError("DMG checksum mismatch.")
            }
            try run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-mountpoint", mount.path, dmg.path])
            attached = true
            let source = mount.appendingPathComponent("\(name).app")
            try validate(source, bundleID: id, version: version)

            let destination = URL(fileURLWithPath: "/Applications/\(name).app")
            guard let previous = Bundle(url: destination), previous.bundleIdentifier == id else {
                throw InstallError("First install \(name) into /Applications manually.")
            }
            let staged = URL(fileURLWithPath: "/Applications/.\(name)-stage-\(UUID().uuidString).app")
            let backup = URL(fileURLWithPath: "/Applications/.\(name)-backup-\(UUID().uuidString).app")
            do {
                try run("/usr/bin/ditto", [source.path, staged.path])
                try validate(staged, bundleID: id, version: version)
                try fm.moveItem(at: destination, to: backup)
                do {
                    try fm.moveItem(at: staged, to: destination)
                    try validate(destination, bundleID: id, version: version)
                } catch {
                    if fm.fileExists(atPath: destination.path) { try? fm.removeItem(at: destination) }
                    try? fm.moveItem(at: backup, to: destination)
                    throw error
                }
                try? fm.removeItem(at: backup)
            } catch {
                try? fm.removeItem(at: staged)
                throw error
            }
            // Apple may ask for approval again because GitHub builds are not notarized.
            try run("/usr/bin/open", [destination.path])
            log("Installed \(name) \(version)")
        } catch {
            log("Update failed: \(error.localizedDescription)")
            // Do not bypass Gatekeeper or request admin access. Retain manual fallback.
            _ = try? run("/usr/bin/open", [dmg.path])
            _ = try? run("/usr/bin/osascript", [
                "-e", "display dialog \"Automatic installation was not permitted. The verified update DMG is open; drag the app into Applications to finish.\" buttons {\"OK\"} default button 1"
            ])
        }
    }

    private static func validate(_ app: URL, bundleID: String, version: String) throws {
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == bundleID,
              (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) == version
        else { throw InstallError("Incorrect app identity or version.") }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
    }

    private static func run(_ executable: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw InstallError("\((executable as NSString).lastPathComponent) failed with \(p.terminationStatus).")
        }
    }

    private static func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let block = try handle.read(upToCount: 1024 * 1024), !block.isEmpty {
            hasher.update(data: block)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func log(_ value: String) {
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacAppInstaller.log")
        let text = "[\(Date())] \(value)\n"
        if !FileManager.default.fileExists(atPath: file.path) {
            _ = FileManager.default.createFile(atPath: file.path, contents: Data())
        }
        if let handle = try? FileHandle(forWritingTo: file) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(text.utf8))
            try? handle.close()
        }
    }

    private struct InstallError: LocalizedError {
        let reason: String
        init(_ reason: String) { self.reason = reason }
        var errorDescription: String? { reason }
    }
}
