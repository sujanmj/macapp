import AppKit

struct MusicPlaylistEntry: Identifiable, Equatable {
    let index: Int
    let title: String
    let artist: String
    let isCurrent: Bool
    var id: Int { index }
}

enum MusicPlaylistParser {
    static func parse(_ descriptor: NSAppleEventDescriptor?) -> [MusicPlaylistEntry] {
        guard let descriptor, descriptor.numberOfItems > 0 else { return [] }
        return (1...descriptor.numberOfItems).compactMap { itemIndex in
            guard let row = descriptor.atIndex(itemIndex), row.numberOfItems >= 3,
                  let indexValue = row.atIndex(1)?.int32Value,
                  let title = row.atIndex(2)?.stringValue,
                  let artist = row.atIndex(3)?.stringValue else { return nil }
            let isCurrent = row.numberOfItems >= 4 && (row.atIndex(4)?.booleanValue ?? false)
            return MusicPlaylistEntry(index: Int(indexValue), title: title, artist: artist, isCurrent: isCurrent)
        }
    }
}
