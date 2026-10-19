import Foundation

@main
struct LocalAppCatalogChecks {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchAppCatalog-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let apps = root.appendingPathComponent("Apps", isDirectory: true)
        let nested = apps.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        for path in [apps.appendingPathComponent("Alpha.app", isDirectory: true), nested.appendingPathComponent("Beta.APP", isDirectory: true)] {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
        try FileManager.default.createDirectory(at: apps.appendingPathComponent("Not an app.bundle", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: apps.appendingPathComponent(".Hidden.app", isDirectory: true), withIntermediateDirectories: true)

        let found = LocalAppCatalog.applications(in: [apps, apps])
        precondition(found.map(\.name) == ["Alpha", "Beta"], "Only top-level application bundles should be listed once and sorted")
        precondition(LocalAppCatalog.applications(in: [root.appendingPathComponent("Missing")]).isEmpty, "Missing roots should be ignored")
        let ids = ["alpha", "beta", "gamma"]
        precondition(AppLauncherNavigation.nextID(currentID: nil, direction: 1, ids: ids) == "alpha", "Down should begin at the first app")
        precondition(AppLauncherNavigation.nextID(currentID: nil, direction: -1, ids: ids) == "gamma", "Up should begin at the last app")
        precondition(AppLauncherNavigation.nextID(currentID: "beta", direction: 1, ids: ids) == "gamma", "Down should advance one result")
        precondition(AppLauncherNavigation.nextID(currentID: "beta", direction: -1, ids: ids) == "alpha", "Up should move to the previous result")
        precondition(AppLauncherNavigation.nextID(currentID: "gamma", direction: 1, ids: ids) == "alpha", "Down should wrap at the last result")
        precondition(AppLauncherNavigation.nextID(currentID: "alpha", direction: -1, ids: ids) == "gamma", "Up should wrap at the first result")
        precondition(AppLauncherNavigation.nextID(currentID: nil, direction: 1, ids: []) == nil, "Empty results should not select an app")
        print("MacNotch local app catalog checks passed")
    }
}
