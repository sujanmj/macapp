import Foundation

enum RecentTrayDestinations {
    static func adding(_ url: URL, to paths: [String], limit: Int = 6) -> [String] {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return [path] + paths.filter { URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath().path != path }.prefix(max(0, limit - 1))
    }
}

struct TrayTransferFailure {
    let source: URL
    let message: String
}

struct TrayTransferResult {
    let copied: [URL]
    let failures: [TrayTransferFailure]
}

enum TrayTransfer {
    /// Copies existing tray items into a chosen folder without replacing or deleting anything.
    static func copy(_ sources: [URL], to destination: URL, fileManager: FileManager = .default) -> TrayTransferResult {
        var copied: [URL] = []
        var failures: [TrayTransferFailure] = []
        let target = destination.standardizedFileURL.resolvingSymlinksInPath()

        for sourceURL in sources {
            let source = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
            guard fileManager.fileExists(atPath: source.path) else {
                failures.append(TrayTransferFailure(source: source, message: "Source no longer exists"))
                continue
            }
            guard source != target, !target.path.hasPrefix(source.path.hasSuffix("/") ? source.path : source.path + "/") else {
                failures.append(TrayTransferFailure(source: source, message: "Destination is inside this source folder"))
                continue
            }

            let candidate = availableURL(for: source.lastPathComponent, in: target, fileManager: fileManager)
            do {
                try fileManager.copyItem(at: source, to: candidate)
                copied.append(candidate)
            } catch {
                failures.append(TrayTransferFailure(source: source, message: error.localizedDescription))
            }
        }
        return TrayTransferResult(copied: copied, failures: failures)
    }

    private static func availableURL(for name: String, in folder: URL, fileManager: FileManager) -> URL {
        let initial = folder.appendingPathComponent(name, isDirectory: false)
        guard fileManager.fileExists(atPath: initial.path) else { return initial }

        let source = URL(fileURLWithPath: name)
        let stem = source.deletingPathExtension().lastPathComponent
        let suffix = source.pathExtension
        var index = 2
        while true {
            let candidateName = suffix.isEmpty ? "\(stem) (\(index))" : "\(stem) (\(index)).\(suffix)"
            let candidate = folder.appendingPathComponent(candidateName, isDirectory: false)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
