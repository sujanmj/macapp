import Foundation
import Darwin

/// Minimal, current-user-only telemetry shared with the sandboxed WidgetKit extension.
struct NotchWidgetSnapshot: Codable {
    let schema: Int
    let date: Date
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let diskFree: UInt64
    let cpu: Double
    let upload: UInt64
    let download: UInt64
    let topApp: String?
    let topBytes: UInt64?

    static var file: URL? {
        guard let entry = getpwuid(getuid()), let home = entry.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: home))
            .appendingPathComponent("Library/Application Support/com.sujanmj.macnotch/widget-snapshot.json")
    }

    static func read() -> NotchWidgetSnapshot? {
        guard let file, let data = try? Data(contentsOf: file) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data, now: Date = Date()) -> NotchWidgetSnapshot? {
        guard data.count < 65_536,
              let value = try? JSONDecoder().decode(Self.self, from: data),
              value.schema == 1, value.date <= now.addingTimeInterval(60),
              value.cpu.isFinite, (0...100).contains(value.cpu),
              (value.topApp?.count ?? 0) <= 256 else { return nil }
        return value
    }

    func write() throws {
        guard let target = Self.file else { return }
        try write(to: target)
    }

    func write(to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(self).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
