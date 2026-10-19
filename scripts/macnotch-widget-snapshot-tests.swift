import Foundation

@main
struct MacNotchWidgetSnapshotTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchWidgetSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let snapshot = NotchWidgetSnapshot(schema: 1, date: Date(), memoryUsed: 4_000, memoryTotal: 8_000,
                                          diskFree: 10_000, cpu: 38.5, upload: 120, download: 340,
                                          topApp: "Editor", topBytes: 2_000)
        let encoded = try JSONEncoder().encode(snapshot)
        guard let decoded = NotchWidgetSnapshot.decode(encoded), decoded.memoryUsed == snapshot.memoryUsed,
              decoded.cpu == snapshot.cpu, decoded.topApp == "Editor" else {
            fatalError("Widget snapshots should round-trip their timestamped system values")
        }

        let invalidCPU = NotchWidgetSnapshot(schema: 1, date: Date(), memoryUsed: 0, memoryTotal: 1,
                                             diskFree: 0, cpu: 140, upload: 0, download: 0,
                                             topApp: nil, topBytes: nil)
        let future = NotchWidgetSnapshot(schema: 1, date: Date().addingTimeInterval(600), memoryUsed: 0, memoryTotal: 1,
                                         diskFree: 0, cpu: 0, upload: 0, download: 0,
                                         topApp: nil, topBytes: nil)
        let wrongSchema = NotchWidgetSnapshot(schema: 9, date: Date(), memoryUsed: 0, memoryTotal: 1,
                                              diskFree: 0, cpu: 0, upload: 0, download: 0,
                                              topApp: nil, topBytes: nil)
        guard NotchWidgetSnapshot.decode(try JSONEncoder().encode(invalidCPU)) == nil,
              NotchWidgetSnapshot.decode(try JSONEncoder().encode(future)) == nil,
              NotchWidgetSnapshot.decode(try JSONEncoder().encode(wrongSchema)) == nil,
              NotchWidgetSnapshot.decode(Data(repeating: 0, count: 65_536)) == nil else {
            fatalError("Widget snapshots should reject invalid, future, oversized, and unknown-schema data")
        }

        let file = folder.appendingPathComponent("private/snapshot.json")
        try snapshot.write(to: file)
        let mode = (try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)?.intValue
        guard mode == 0o600, NotchWidgetSnapshot.decode(try Data(contentsOf: file))?.topBytes == 2_000 else {
            fatalError("Widget telemetry should be atomic round-trippable data with current-user-only file permissions")
        }
        print("MacNotch WidgetKit snapshot checks passed")
    }
}
