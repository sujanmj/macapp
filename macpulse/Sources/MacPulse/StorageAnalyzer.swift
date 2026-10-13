import AppKit
import Foundation

enum StorageCategory: String, CaseIterable, Identifiable {
    case videos = "Videos"
    case images = "Images"
    case audio = "Audio"
    case installers = "Installers & Archives"
    case documents = "Documents"
    case developer = "Developer Files"
    case other = "Other"
    var id: String { rawValue }

    static func classify(extension ext: String) -> StorageCategory {
        switch ext.lowercased() {
        case "mov", "mp4", "m4v", "mkv", "avi", "webm": return .videos
        case "png", "jpg", "jpeg", "heic", "gif", "tiff", "webp", "raw": return .images
        case "mp3", "m4a", "wav", "aac", "flac", "aiff": return .audio
        case "dmg", "pkg", "zip", "7z", "rar", "tar", "gz", "xz": return .installers
        case "pdf", "doc", "docx", "txt", "rtf", "pptx", "xlsx", "pages", "numbers", "key": return .documents
        case "xcarchive", "ipa", "a", "o", "dylib", "map", "log", "sqlite": return .developer
        default: return .other
        }
    }
}

struct StorageEntry: Identifiable, Hashable {
    let url: URL
    let size: UInt64
    let modified: Date?
    let category: StorageCategory
    var id: String { url.path }
}

struct StorageScanResult {
    let folder: URL
    let files: [StorageEntry]
    let examinedCount: Int
    let wasLimited: Bool

    var totalBytes: UInt64 { files.reduce(0) { $0 + $1.size } }
    var categoryTotals: [(category: StorageCategory, size: UInt64, count: Int)] {
        StorageCategory.allCases.compactMap { category in
            let group = files.filter { $0.category == category }
            guard !group.isEmpty else { return nil }
            return (category, group.reduce(0) { $0 + $1.size }, group.count)
        }.sorted { $0.size > $1.size }
    }
    var biggest: [StorageEntry] { files.sorted { $0.size > $1.size } }
}

/// Read-only, scope-limited storage inventory. Never follows symbolic links or
/// descends into application bundles. No Home/Library or system-wide auto-scan.
enum StorageAnalyzer {
    static let fileLimit = 20_000
    static let displayLimit = 300

    static func scan(_ root: URL) -> StorageScanResult {
        let fm = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey,
            .fileSizeKey, .contentModificationDateKey
        ]
        guard let enumerator = fm.enumerator(
            at: root, includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return StorageScanResult(folder: root, files: [], examinedCount: 0, wasLimited: false) }

        var files: [StorageEntry] = []
        var examined = 0
        var limited = false
        for case let url as URL in enumerator {
            examined += 1
            if examined > fileLimit {
                limited = true
                break
            }
            guard let attrs = try? url.resourceValues(forKeys: resourceKeys),
                  attrs.isRegularFile == true,
                  attrs.isSymbolicLink != true,
                  attrs.isPackage != true,
                  let fileSize = attrs.fileSize, fileSize >= 0 else { continue }
            let entry = StorageEntry(url: url, size: UInt64(fileSize),
                                     modified: attrs.contentModificationDate,
                                     category: StorageCategory.classify(extension: url.pathExtension))
            files.append(entry)
        }
        return StorageScanResult(folder: root, files: files, examinedCount: examined, wasLimited: limited)
    }

    static func isSafeFile(_ entry: StorageEntry, within root: URL) -> Bool {
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath().path
        let canonicalFile = entry.url.standardizedFileURL.resolvingSymlinksInPath().path
        guard canonicalFile.hasPrefix(canonicalRoot + "/"),
              canonicalFile != canonicalRoot else { return false }
        let fm = FileManager.default
        guard let attributes = try? fm.attributesOfItem(atPath: canonicalFile),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let n = attributes[.size] as? NSNumber,
              n.uint64Value == entry.size,
              let props = try? entry.url.resourceValues(forKeys: [.isSymbolicLinkKey]),
              props.isSymbolicLink != true else { return false }
        return true
    }

    static func moveToTrash(
        _ chosen: [StorageEntry], root: URL,
        completion: @escaping (String) -> Void
    ) {
        let eligible = chosen.filter { isSafeFile($0, within: root) }
        guard !eligible.isEmpty else {
            completion("No selected files passed safety checks. Nothing was changed.")
            return
        }
        NSWorkspace.shared.recycle(eligible.map(\.url)) { moved, error in
            DispatchQueue.main.async {
                if let error {
                    completion("macOS reported a problem while moving files to Trash: \(error.localizedDescription). Review Trash and the folder.")
                } else {
                    completion("Moved \(moved.count) of \(chosen.count) selected files to Trash. Restore them through Finder if needed.")
                }
            }
        }
    }
}
