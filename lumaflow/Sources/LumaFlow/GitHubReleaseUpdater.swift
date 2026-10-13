import AppKit
import CryptoKit
import Foundation

/// Manual, user-initiated updates from this repository's GitHub Releases.
/// Never executes a downloaded program or replaces the running application.
@MainActor
enum GitHubReleaseUpdater {
    private static let releasesEndpoint =
        URL(string: "https://api.github.com/repos/sujanmj/macapp/releases?per_page=100")!

    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: String
        let digest: String?
    }

    static func check(appName: String, releasePrefix: String) async {
        let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        do {
            var request = URLRequest(url: releasesEndpoint)
            request.timeoutInterval = 25
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("MacApp-Updater/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError("Unable to read GitHub Releases. Please try again.")
            }
            let releases = try JSONDecoder().decode([Release].self, from: data)
            let candidates = releases.compactMap { release -> (Release, String)? in
                guard !release.draft, !release.prerelease,
                      release.tag_name.hasPrefix(releasePrefix) else { return nil }
                let version = String(release.tag_name.dropFirst(releasePrefix.count))
                guard versionParts(version) != nil else { return nil }
                return (release, version)
            }
            guard let latest = candidates.max(by: { compareVersions($0.1, $1.1) == .orderedAscending }) else {
                alert("No releases found", "No published \(appName) installers are available yet.")
                return
            }
            if compareVersions(latest.1, installed) != .orderedDescending {
                alert("You're up to date", "\(appName) \(installed) is the latest published version.")
                return
            }

            let expectedName = "\(appName)-v\(latest.1).dmg"
            guard let asset = latest.0.assets.first(where: { $0.name == expectedName }) else {
                alert("Update not ready", "\(appName) \(latest.1) was published, but its DMG is not available yet.")
                return
            }
            guard let assetURL = URL(string: asset.browser_download_url),
                  assetURL.scheme == "https", assetURL.host == "github.com",
                  assetURL.path == "/sujanmj/macapp/releases/download/\(latest.0.tag_name)/\(expectedName)",
                  let digest = asset.digest?.lowercased(),
                  digest.hasPrefix("sha256:"), digest.dropFirst(7).count == 64 else {
                throw UpdateError("The GitHub release has no valid verified download or SHA-256 checksum.")
            }

            let confirmation = NSAlert()
            confirmation.messageText = "\(appName) \(latest.1) is available"
            confirmation.informativeText =
                "Installed: \(installed)\nAvailable: \(latest.1)\n\nDownload and verify the official GitHub DMG? You'll install it by dragging the app into Applications."
            confirmation.alertStyle = .informational
            confirmation.addButton(withTitle: "Download Update")
            confirmation.addButton(withTitle: "Not Now")
            guard confirmation.runModal() == .alertFirstButtonReturn else { return }

            var downloadRequest = URLRequest(url: assetURL)
            downloadRequest.timeoutInterval = 180
            downloadRequest.setValue("MacApp-Updater/1.0", forHTTPHeaderField: "User-Agent")
            let (temporaryURL, downloadResponse) = try await URLSession.shared.download(for: downloadRequest)
            guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError("The GitHub DMG download did not complete successfully.")
            }
            let verified = try sha256(file: temporaryURL)
            guard verified == String(digest.dropFirst(7)) else {
                throw UpdateError("The downloaded DMG failed SHA-256 verification and was not opened.")
            }

            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ??
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
            let destination = downloads.appendingPathComponent(expectedName)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)

            if NSWorkspace.shared.open(destination) {
                alert("Update ready to install",
                      "Verified \(expectedName) in Downloads and opened it. Drag \(appName).app into Applications to replace the old version, then relaunch.\n\nThe update does not install silently.")
            } else {
                alert("Update downloaded",
                      "Verified \(expectedName) in your Downloads folder. Double-click it and drag \(appName).app into Applications.")
            }
        } catch {
            alert("Update failed", error.localizedDescription)
        }
    }

    private struct UpdateError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    private static func versionParts(_ value: String) -> [Int]? {
        let fields = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...4).contains(fields.count) else { return nil }
        let parts = fields.compactMap { Int($0) }
        return parts.count == fields.count && parts.allSatisfy { $0 >= 0 } ? parts : nil
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = versionParts(lhs) ?? [0]
        let b = versionParts(rhs) ?? [0]
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x < y { return .orderedAscending }
            if x > y { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func sha256(file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let bytes = try handle.read(upToCount: 1024 * 1024), !bytes.isEmpty {
            hasher.update(data: bytes)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func alert(_ title: String, _ message: String) {
        let dialog = NSAlert()
        dialog.messageText = title
        dialog.informativeText = message
        dialog.runModal()
    }
}
