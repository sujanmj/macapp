import AppKit

@main
struct MacNotchMediaPlaylistTests {
    static func main() {
        let rows = NSAppleEventDescriptor.list()
        let first = NSAppleEventDescriptor.list()
        first.insert(NSAppleEventDescriptor(int32: 1), at: 1)
        first.insert(NSAppleEventDescriptor(string: "Current song"), at: 2)
        first.insert(NSAppleEventDescriptor(string: "Artist"), at: 3)
        first.insert(NSAppleEventDescriptor(boolean: true), at: 4)
        rows.insert(first, at: 1)

        let second = NSAppleEventDescriptor.list()
        second.insert(NSAppleEventDescriptor(int32: 2), at: 1)
        second.insert(NSAppleEventDescriptor(string: "Next song"), at: 2)
        second.insert(NSAppleEventDescriptor(string: "Another artist"), at: 3)
        second.insert(NSAppleEventDescriptor(boolean: false), at: 4)
        rows.insert(second, at: 2)

        let parsed = MusicPlaylistParser.parse(rows)
        precondition(parsed == [
            MusicPlaylistEntry(index: 1, title: "Current song", artist: "Artist", isCurrent: true),
            MusicPlaylistEntry(index: 2, title: "Next song", artist: "Another artist", isCurrent: false)
        ], "Playlist rows should retain item, artist, and now-playing state")
        precondition(MusicPlaylistParser.parse(nil).isEmpty, "Missing player data should produce an empty preview")
        let malformed = NSAppleEventDescriptor.list()
        malformed.insert(NSAppleEventDescriptor(string: "bad row"), at: 1)
        precondition(MusicPlaylistParser.parse(malformed).isEmpty, "Malformed player rows should be skipped")
        print("MacNotch media playlist checks passed")
    }
}
