import AppKit
import Foundation
import Darwin

struct RunningAppMemory: Identifiable {
    let pid: pid_t
    let name: String
    let bundleID: String
    let residentBytes: UInt64
    let launchDate: Date?
    let executableURL: URL?
    var id: pid_t { pid }
}

/// Lists normal user-facing apps. Never kills system processes or force-quits apps.
enum MemoryTools {
    static func runningApps() -> [RunningAppMemory] {
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/bin/ps")
        command.arguments = ["-axo", "pid=,rss="]
        let pipe = Pipe()
        command.standardOutput = pipe
        command.standardError = FileHandle.nullDevice
        guard (try? command.run()) != nil else { return [] }
        let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
        command.waitUntilExit()
        guard command.terminationStatus == 0,
              let output = String(data: bytes, encoding: .utf8) else { return [] }
        var resident: [pid_t: UInt64] = [:]
        for line in output.components(separatedBy: .newlines) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, let pid = pid_t(fields[0]),
                  let kb = UInt64(fields[1]) else { continue }
            resident[pid] = kb * 1024
        }
        let fm = FileManager.default
        let userApps = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").path + "/"
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular,
                  app.processIdentifier != getpid(),
                  let url = app.bundleURL,
                  url.resolvingSymlinksInPath().path.hasPrefix("/Applications/") || url.resolvingSymlinksInPath().path.hasPrefix(userApps),
                  let memory = resident[app.processIdentifier] else { return nil }
            return RunningAppMemory(pid: app.processIdentifier,
                                    name: app.localizedName ?? url.deletingPathExtension().lastPathComponent,
                                    bundleID: app.bundleIdentifier ?? "", residentBytes: memory,
                                    launchDate: app.launchDate, executableURL: app.executableURL)
        }.sorted { $0.residentBytes > $1.residentBytes }
    }

    /// Requests a graceful app quit, which lets the app ask the user to save work.
    static func requestQuit(_ item: RunningAppMemory) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: item.pid),
              app.activationPolicy == .regular,
              app.processIdentifier != getpid(),
              !app.isTerminated,
              app.launchDate == item.launchDate,
              app.executableURL == item.executableURL,
              app.bundleIdentifier == item.bundleID,
              let bundlePath = app.bundleURL?.resolvingSymlinksInPath().path,
              bundlePath.hasPrefix("/Applications/") ||
              bundlePath.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/")
        else { return false }
        return app.terminate()
    }
}
