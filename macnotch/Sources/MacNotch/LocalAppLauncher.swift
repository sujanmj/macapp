import AppKit
import Foundation
import SwiftUI

struct LaunchableApp: Identifiable, Hashable {
    let url: URL
    let bundleIdentifier: String?

    var id: String { bundleIdentifier ?? url.standardizedFileURL.path }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum AppLauncherNavigation {
    static func nextID(currentID: String?, direction: Int, ids: [String]) -> String? {
        guard !ids.isEmpty, direction != 0 else { return nil }
        guard let currentID, let currentIndex = ids.firstIndex(of: currentID) else {
            return direction > 0 ? ids.first : ids.last
        }
        let nextIndex = (currentIndex + (direction > 0 ? 1 : -1) + ids.count) % ids.count
        return ids[nextIndex]
    }
}

enum LocalAppCatalog {
    static func applications(in roots: [URL], fileManager: FileManager = .default) -> [LaunchableApp] {
        var byPath: [String: LaunchableApp] = [:]
        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
                      (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                enumerator.skipDescendants()
                let standardized = url.standardizedFileURL
                byPath[standardized.path] = LaunchableApp(
                    url: standardized,
                    bundleIdentifier: Bundle(url: standardized)?.bundleIdentifier
                )
            }
        }
        return byPath.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func defaultRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]
    }
}

@MainActor
final class AppLauncherStore: ObservableObject {
    @Published private(set) var applications: [LaunchableApp] = []
    @Published private(set) var favoriteIDs: Set<String> = []
    @Published var search = ""
    @Published var favoritesOnly = true
    @Published private(set) var message = "Choose an app to open it."

    private let favoritesKey = "macNotchFavoriteAppIDs"

    init() {
        favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
        refresh()
    }

    var visibleApplications: [LaunchableApp] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return applications.filter { app in
            (!favoritesOnly || favoriteIDs.contains(app.id))
                && (query.isEmpty || app.name.localizedStandardContains(query)
                    || (app.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false))
        }
    }

    func refresh() {
        applications = LocalAppCatalog.applications(in: LocalAppCatalog.defaultRoots())
        message = "Found \(applications.count) apps on this Mac."
    }

    func toggleFavorite(_ app: LaunchableApp) {
        if favoriteIDs.contains(app.id) { favoriteIDs.remove(app.id) }
        else { favoriteIDs.insert(app.id) }
        UserDefaults.standard.set(favoriteIDs.sorted(), forKey: favoritesKey)
    }

    func launch(_ app: LaunchableApp) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                self?.message = error.map { "Could not open \(app.name): \($0.localizedDescription)" } ?? "Opened \(app.name)."
            }
        }
    }
}
