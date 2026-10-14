import Foundation
import Darwin

/// A single atomic, versioned record. No private data beyond the top app name.
struct WidgetSnapshot: Codable {
    let schema: Int
    let date: Date
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let diskFree: UInt64
    let cpu: Double?
    let upload: Double?
    let download: Double?
    let topApp: String?
    let topBytes: UInt64?

    static var file: URL? {
        guard let entry = getpwuid(getuid()), let home = entry.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: home))
            .appendingPathComponent("Library/Application Support/com.sujanmj.macpulse/telemetry.json")
    }
    static func read() -> WidgetSnapshot? {
        guard let file, let data = try? Data(contentsOf: file), data.count < 65536,
              let value = try? JSONDecoder().decode(Self.self, from: data),
              value.schema == 1, value.date <= Date().addingTimeInterval(60) else { return nil }
        return value
    }
    func write() throws {
        guard let file = Self.file else { return }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(self).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
