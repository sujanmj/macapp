import Foundation

@main
struct MeetingRecordingLibraryChecks {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchMeetingLibrary-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let old = root.appendingPathComponent("old.MOV")
        let recent = root.appendingPathComponent("recent.mp4")
        let audioOnly = root.appendingPathComponent("audio-only.m4a")
        let ignored = root.appendingPathComponent("notes.txt")
        let hidden = root.appendingPathComponent(".hidden.mov")
        let folderNamedLikeMovie = root.appendingPathComponent("folder.mov", isDirectory: true)
        for file in [old, recent, audioOnly, ignored, hidden] { try Data([1, 2, 3]).write(to: file) }
        try FileManager.default.createDirectory(at: folderNamedLikeMovie, withIntermediateDirectories: true)
        let oldDate = Date(timeIntervalSince1970: 100)
        let recentDate = Date(timeIntervalSince1970: 200)
        let audioDate = Date(timeIntervalSince1970: 300)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: recentDate], ofItemAtPath: recent.path)
        try FileManager.default.setAttributes([.modificationDate: audioDate], ofItemAtPath: audioOnly.path)

        let entries = MeetingRecordingLibrary.list(in: root)
        precondition(entries.map(\.url.lastPathComponent) == ["audio-only.m4a", "recent.mp4", "old.MOV"], "Regular screen and audio recordings should be listed, newest first")
        precondition(entries.allSatisfy { $0.size == 3 }, "File size should be available for every recording")
        let audioEntry = entries.first(where: { $0.url.lastPathComponent == audioOnly.lastPathComponent })
        let movieEntry = entries.first(where: { $0.url.lastPathComponent == recent.lastPathComponent })
        precondition(movieEntry?.transcriptURL.lastPathComponent == "recent.txt", "Transcript path should sit beside its movie")
        precondition(movieEntry?.subtitleURL.lastPathComponent == "recent.srt", "Subtitle path should sit beside its movie")
        precondition(audioEntry?.transcriptURL.lastPathComponent == "audio-only.txt", "Audio-only recordings should support local transcript sidecars")
        precondition(audioEntry?.subtitleURL.lastPathComponent == "audio-only.srt", "Audio-only recordings should support timed subtitle sidecars")
        try Data("transcript".utf8).write(to: audioOnly.deletingPathExtension().appendingPathExtension("txt"))
        try Data("captions".utf8).write(to: audioOnly.deletingPathExtension().appendingPathExtension("srt"))
        precondition(audioEntry?.associatedFiles.map(\.lastPathComponent) == ["audio-only.m4a", "audio-only.txt", "audio-only.srt"], "Cleanup should include a recording and its existing transcript/caption sidecars")
        precondition(movieEntry?.associatedFiles.map(\.lastPathComponent) == ["recent.mp4"], "Cleanup should leave unrelated recordings and missing sidecars alone")
        precondition(MeetingRecordingLibrary.list(in: root, limit: 1).count == 1, "The configured result limit should be respected")
        precondition(MeetingRecordingLibrary.list(in: root, limit: 0).isEmpty, "A nonpositive result limit should return no rows")

        print("MacNotch meeting recording library checks passed")
    }
}
