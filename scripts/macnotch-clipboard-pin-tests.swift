import Foundation

@main
struct MacNotchClipboardPinTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchClipboardPins-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("PinnedClipboard.json")
        let first = ClipboardRecord(title: "A note", text: "private test text", payload: [["public.utf8-plain-text": Data("private test text".utf8)]])
        try ClipboardPinStore.save([first], to: file)
        let loaded = ClipboardPinStore.load(from: file)
        precondition(loaded.count == 1 && loaded[0].id == first.id && loaded[0].text == first.text && loaded[0].payload == first.payload,
                     "Pinned data must round-trip without losing rich payloads or identity.")

        var rejectedOversize = false
        let oversized = ClipboardRecord(title: "Too large", text: nil,
                                        payload: [["public.data": Data(repeating: 0, count: ClipboardPinStore.maximumBytes)]])
        do { try ClipboardPinStore.save([first, oversized], to: file) }
        catch { rejectedOversize = true }
        precondition(rejectedOversize, "Pinned data must obey its size limit.")
        precondition(ClipboardPinStore.load(from: file).map(\.id) == [first.id], "Failed saves must leave existing pins intact.")
        var rejectedCount = false
        do { try ClipboardPinStore.save((0...ClipboardPinStore.maximumRecords).map { ClipboardRecord(title: "Clip \($0)", text: nil, payload: []) }, to: file) }
        catch { rejectedCount = true }
        precondition(rejectedCount, "Pinned data must reject more than 100 records without truncating silently.")
        precondition(ClipboardPinStore.load(from: file).map(\.id) == [first.id], "Failed count validation must leave existing pins intact.")

        let corrupted = folder.appendingPathComponent("Corrupted.json")
        try Data("not json".utf8).write(to: corrupted)
        precondition(ClipboardPinStore.load(from: corrupted).isEmpty, "Invalid pin files must fail closed.")
        print("MacNotch pinned clipboard checks passed")
    }
}
