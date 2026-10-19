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
        print("MacNotch local app catalog checks passed")
    }
}
