import Foundation

@main
struct MeetingRecordingLibraryChecks {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchMeetingLibrary-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let old = root.appendingPathComponent("old.MOV")
        let recent = root.appendingPathComponent("recent.mp4")
        let ignored = root.appendingPathComponent("notes.txt")
        let hidden = root.appendingPathComponent(".hidden.mov")
        let folderNamedLikeMovie = root.appendingPathComponent("folder.mov", isDirectory: true)
        for file in [old, recent, ignored, hidden] { try Data([1, 2, 3]).write(to: file) }
        try FileManager.default.createDirectory(at: folderNamedLikeMovie, withIntermediateDirectories: true)
        let oldDate = Date(timeIntervalSince1970: 100)
        let recentDate = Date(timeIntervalSince1970: 200)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: recentDate], ofItemAtPath: recent.path)

        let entries = MeetingRecordingLibrary.list(in: root)
        precondition(entries.map(\.url.lastPathComponent) == ["recent.mp4", "old.MOV"], "Only regular movie files should be listed, newest first")
        precondition(entries.allSatisfy { $0.size == 3 }, "File size should be available for every recording")
        precondition(entries[0].transcriptURL.lastPathComponent == "recent.txt", "Transcript path should sit beside its movie")
        precondition(entries[0].subtitleURL.lastPathComponent == "recent.srt", "Subtitle path should sit beside its movie")
        precondition(MeetingRecordingLibrary.list(in: root, limit: 1).count == 1, "The configured result limit should be respected")
        precondition(MeetingRecordingLibrary.list(in: root, limit: 0).isEmpty, "A nonpositive result limit should return no rows")

        print("MacNotch meeting recording library checks passed")
    }
}
