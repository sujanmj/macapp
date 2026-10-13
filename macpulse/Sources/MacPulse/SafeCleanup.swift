import AppKit
import Foundation
import CryptoKit

struct CleanupCandidate: Identifiable, Hashable {
    let url: URL
    let size: UInt64
    var id: String { url.path }
}

/// Deliberately conservative: only old user-owned .log/.txt files under
/// ~/Library/Logs. Never touches system folders, app databases or browser data.
enum SafeCleanup {
    static func scan() -> [CleanupCandidate] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        let cutoff = Date().addingTimeInterval(-14 * 24 * 3600)
        let fm = FileManager.default
        guard let items = fm.enumerator(at: root, includingPropertiesForKeys:
            [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var results: [CleanupCandidate] = []
        for case let url as URL in items {
            if results.count >= 2000 { break }
            guard ["log", "txt"].contains(url.pathExtension.lowercased()),
                  let info = try? url.resourceValues(forKeys:
                    [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey]),
                  info.isRegularFile == true, info.isSymbolicLink != true,
                  let age = info.contentModificationDate, age < cutoff,
                  let size = info.fileSize, size > 0 && size <= 50_000_000
            else { continue }
            results.append(CleanupCandidate(url: url, size: UInt64(size)))
        }
        return results.sorted { $0.size > $1.size }
    }

    static func trash(_ candidates: [CleanupCandidate], completion: @escaping (String) -> Void) {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true).resolvingSymlinksInPath()
        let prefix = root.path + "/"
        let fm = FileManager.default
        let validated = candidates.compactMap { item -> URL? in
            let resolved = item.url.resolvingSymlinksInPath()
            guard resolved.path.hasPrefix(prefix), !resolved.hasDirectoryPath,
                  let attrs = try? fm.attributesOfItem(atPath: resolved.path),
                  attrs[.type] as? FileAttributeType == .typeRegular else { return nil }
            return resolved
        }
        guard !validated.isEmpty else {
            completion("No eligible log files to move to Trash.")
            return
        }
        NSWorkspace.shared.recycle(validated) { moved, error in
            DispatchQueue.main.async {
                if let error { completion("Cleanup error: \(error.localizedDescription)") }
                else { completion("Moved \(moved.count) log files to Trash. You can restore them in Finder.") }
            }
        }
    }
}

struct DuplicateGroup: Identifiable {
    let size: UInt64
    let urls: [URL]
    var id: String { urls.first?.path ?? UUID().uuidString }
}

/// A read-only exact-duplicate scanner. No automatic duplicate deletion.
enum DuplicateFinder {
    static func scan(_ folder: URL) -> [DuplicateGroup] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: folder, includingPropertiesForKeys:
            [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var bySize: [UInt64: [URL]] = [:]
        var checked = 0
        for case let url as URL in en {
            checked += 1
            if checked > 3000 { break }
            guard let props = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
                  props.isRegularFile == true, props.isSymbolicLink != true,
                  let length = props.fileSize, length > 0, length < 200_000_000 else { continue }
            bySize[UInt64(length), default: []].append(url)
        }
        var groups: [DuplicateGroup] = []
        for (size, files) in bySize where files.count > 1 {
            var hashes: [String: [URL]] = [:]
            for file in files {
                guard let handle = try? FileHandle(forReadingFrom: file) else { continue }
                var sha = SHA256()
                do {
                    while let block = try handle.read(upToCount: 1024 * 1024), !block.isEmpty {
                        sha.update(data: block)
                    }
                    let key = sha.finalize().map { String(format: "%02x", $0) }.joined()
                    hashes[key, default: []].append(file)
                } catch { }
                try? handle.close()
            }
            for (_, candidates) in hashes where candidates.count > 1 {
                groups.append(DuplicateGroup(size: size, urls: candidates))
            }
        }
        return groups.sorted { $0.size * UInt64($0.urls.count - 1) > $1.size * UInt64($1.urls.count - 1) }
    }
}
