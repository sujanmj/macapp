import Foundation

struct MeetingRecording: Identifiable, Equatable {
    let url: URL
    let modifiedAt: Date
    let size: Int64

    var id: String { url.standardizedFileURL.path }
    var transcriptURL: URL { url.deletingPathExtension().appendingPathExtension("txt") }
    var subtitleURL: URL { url.deletingPathExtension().appendingPathExtension("srt") }
}

enum MeetingRecordingLibrary {
    static func list(in folder: URL, limit: Int = 50, fileManager: FileManager = .default) -> [MeetingRecording] {
        guard limit > 0,
              let urls = try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return urls.compactMap { url -> MeetingRecording? in
            guard ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  let modifiedAt = values.contentModificationDate else { return nil }
            return MeetingRecording(url: url, modifiedAt: modifiedAt, size: Int64(size))
        }
        .sorted {
            if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
            return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }
}
