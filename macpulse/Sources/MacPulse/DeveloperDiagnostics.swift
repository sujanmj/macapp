import Foundation

struct DeveloperFolderReport: Identifiable {
    let name: String
    let note: String
    let url: URL
    let exists: Bool
    let measuredBytes: UInt64
    let scannedFiles: Int
    let partial: Bool
    var id: String { url.path }
}

struct DeveloperToolPresence: Identifiable {
    let title: String
    let installed: Bool
    let location: String?
    var id: String { title }
}

/// Estimates named user-scoped developer caches and archives. Read-only.
enum DeveloperDiagnostics {
    private static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static func scan() -> [DeveloperFolderReport] {
        let locations: [(String, String, String)] = [
            ("Xcode DerivedData", "Regenerable build products, but can contain checkouts and build logs; review individually.", "Library/Developer/Xcode/DerivedData"),
            ("Xcode Archives", "May contain irreplaceable release archives; NEVER treat as cache for automatic deletion.", "Library/Developer/Xcode/Archives"),
            ("Simulator Caches", "Simulator-managed content; avoid deleting while simulators are running.", "Library/Developer/CoreSimulator/Caches"),
            ("Homebrew Cache", "Cached downloads; review first, and prefer brew's own maintenance for cleanup.", "Library/Caches/Homebrew"),
            ("npm Cache", "Node package cache. Deleting may require re-downloading packages.", ".npm/_cacache"),
            ("Gradle Cache", "Build dependencies and metadata; do not remove while builds are running.", ".gradle/caches"),
            ("pip Cache", "Python wheel/download cache; deleting may trigger package downloads.", "Library/Caches/pip")
        ]
        return locations.map { name, note, relativePath in
            let url = home.appendingPathComponent(relativePath, isDirectory: true)
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true else {
                return DeveloperFolderReport(name: name, note: note, url: url,
                                             exists: false, measuredBytes: 0,
                                             scannedFiles: 0, partial: false)
            }
            let scan = StorageAnalyzer.scan(url)
            return DeveloperFolderReport(name: name, note: note, url: url,
                                         exists: true, measuredBytes: scan.totalBytes,
                                         scannedFiles: scan.files.count, partial: scan.wasLimited)
        }
    }

    static func installedTools() -> [DeveloperToolPresence] {
        let locations: [(String, [String])] = [
            ("Git", ["/opt/homebrew/bin/git", "/usr/bin/git"]),
            ("Xcode", ["/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"]),
            ("Docker", ["/opt/homebrew/bin/docker", "/usr/local/bin/docker"]),
            ("Homebrew", ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]),
            ("Terraform", ["/opt/homebrew/bin/terraform", "/usr/local/bin/terraform"]),
            ("kubectl", ["/opt/homebrew/bin/kubectl", "/usr/local/bin/kubectl"]),
            ("Node", ["/opt/homebrew/bin/node", "/usr/local/bin/node"]),
            ("Python", ["/opt/homebrew/bin/python3", "/usr/local/bin/python3"])
        ]
        return locations.map { label, paths in
            let found = paths.first { FileManager.default.isExecutableFile(atPath: $0) }
            return DeveloperToolPresence(title: label, installed: found != nil, location: found)
        }
    }
}
