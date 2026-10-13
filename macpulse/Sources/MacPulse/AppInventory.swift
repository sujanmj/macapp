import AppKit
import Foundation

struct InstalledMacApp: Identifiable {
    let url: URL
    let name: String
    let bundleID: String?
    let version: String
    let modified: Date?
    let isRunning: Bool
    var id: String { url.path }
}

/// Restricted to user-installable Applications folders, never System/Applications.
enum AppInventory {
    static func list() -> [InstalledMacApp] {
        let roots: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]
        let runningIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var seen = Set<String>()
        var apps: [InstalledMacApp] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [
                    .isPackageKey, .isSymbolicLinkKey, .contentModificationDateKey
                ], options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            var count = 0
            for case let url as URL in enumerator {
                count += 1
                if count > 5_000 { break }
                guard url.pathExtension.lowercased() == "app",
                      url.standardizedFileURL.path.hasPrefix(root.path + "/"),
                      !seen.contains(url.path),
                      let values = try? url.resourceValues(forKeys: [
                        .isPackageKey, .isSymbolicLinkKey, .contentModificationDateKey
                      ]),
                      values.isPackage == true, values.isSymbolicLink != true,
                      let bundle = Bundle(url: url)
                else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                    (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                    url.deletingPathExtension().lastPathComponent
                let id = bundle.bundleIdentifier
                let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Unknown"
                apps.append(InstalledMacApp(url: url, name: name, bundleID: id,
                                            version: version, modified: values.contentModificationDate,
                                            isRunning: id.map { runningIDs.contains($0) } ?? false))
                seen.insert(url.path)
                if apps.count > 1_000 { return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Only a selected top-level application bundle may be recycled. Never
    /// deletes Application Support, containers, preferences or login agents.
    static func moveToTrash(_ item: InstalledMacApp, completion: @escaping (String) -> Void) {
        let fm = FileManager.default
        let path = item.url.standardizedFileURL.path
        let roots = ["/Applications", fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]
        guard roots.contains(where: { path.hasPrefix($0 + "/") }),
              path.hasSuffix(".app"),
              !path.hasPrefix("/System/"),
              item.bundleID != Bundle.main.bundleIdentifier,
              !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == item.bundleID }),
              (try? item.url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true,
              fm.fileExists(atPath: path),
              Bundle(url: item.url)?.bundleIdentifier == item.bundleID
        else {
            completion("The app is running, protected, changed since the scan or isn't in an allowed Applications folder. Nothing moved.")
            return
        }
        NSWorkspace.shared.recycle([item.url]) { moved, error in
            DispatchQueue.main.async {
                if let error {
                    completion("macOS couldn't move the app to Trash: \(error.localizedDescription). Use Finder if permission is needed.")
                } else {
                    completion("Moved \(moved.count) application bundle to Trash. Preferences and support files were NOT removed. Restore it from Trash if needed.")
                }
            }
        }
    }
}

struct BrewOutdatedCask: Identifiable {
    let token: String
    let installedVersion: String
    let currentVersion: String
    var id: String { token }
}

/// Optional read-only Homebrew metadata. No homebrew installation, network
/// update, upgrade or automatically executed maintenance.
enum BrewCaskReview {
    static func outdated() -> [BrewOutdatedCask] {
        let locations = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let path = locations.first(where: FileManager.default.isExecutableFile(atPath:)) else { return [] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["outdated", "--cask", "--json=v2"]
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_ANALYTICS"] = "1"
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let casks = obj["casks"] as? [[String: Any]] else { return [] }
            return casks.compactMap { record in
                guard let token = record["name"] as? String else { return nil }
                let current = record["current_version"] as? String ?? "Unknown"
                let installed = (record["installed_versions"] as? [String])?.joined(separator: ", ") ?? "Unknown"
                return BrewOutdatedCask(token: token, installedVersion: installed, currentVersion: current)
            }.sorted { $0.token < $1.token }
        } catch { return [] }
    }
}
