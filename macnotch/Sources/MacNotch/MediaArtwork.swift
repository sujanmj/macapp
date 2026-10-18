import AppKit
import Foundation

enum MediaArtwork {
    static func spotifyImageURL(_ value: String?) -> URL? {
        guard let value,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              host == "i.scdn.co" || host.hasSuffix(".scdn.co") || host == "image-cdn-ak.spotifycdn.com" || host.hasSuffix(".spotifycdn.com"),
              components.user == nil, components.password == nil else { return nil }
        return components.url
    }

    static func image(data: Data) -> NSImage? {
        guard !data.isEmpty, data.count <= 8 * 1024 * 1024,
              let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        return image
    }
}
