import Foundation

struct ClipboardRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let text: String?
    let payload: [[String: Data]]

    init(id: UUID = UUID(), date: Date = Date(), title: String, text: String?, payload: [[String: Data]]) {
        self.id = id
        self.date = date
        self.title = title
        self.text = text
        self.payload = payload
    }
}

enum ClipboardPinStore {
    static let maximumBytes = 8_000_000
    static let maximumRecords = 100

    static func load(from url: URL) -> [ClipboardRecord] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= maximumBytes,
              let data = try? Data(contentsOf: url), data.count <= maximumBytes,
              let records = try? JSONDecoder().decode([ClipboardRecord].self, from: data) else { return [] }
        var seen = Set<UUID>()
        return records.filter { seen.insert($0.id).inserted }.prefix(maximumRecords).map { $0 }
    }

    static func save(_ records: [ClipboardRecord], to url: URL) throws {
        var seen = Set<UUID>()
        let unique = records.filter { seen.insert($0.id).inserted }
        guard unique.count <= maximumRecords else { throw ClipboardPinError.tooManyRecords }
        let data = try JSONEncoder().encode(unique)
        guard data.count <= maximumBytes else { throw ClipboardPinError.capacityExceeded }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

private enum ClipboardPinError: LocalizedError {
    case capacityExceeded
    case tooManyRecords
    var errorDescription: String? {
        switch self {
        case .capacityExceeded: "Pinned clips are limited to 8 MB on this Mac. Unpin an item before saving more."
        case .tooManyRecords: "Pinned clips are limited to 100 items on this Mac. Unpin an item before saving more."
        }
    }
}
