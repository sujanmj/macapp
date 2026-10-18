import AppKit
import Foundation

@main
struct MacNotchMediaArtworkTests {
    static func main() {
        precondition(MediaArtwork.spotifyImageURL("https://i.scdn.co/image/abc")?.host == "i.scdn.co")
        precondition(MediaArtwork.spotifyImageURL("https://image-cdn-ak.spotifycdn.com/image/abc") != nil)
        precondition(MediaArtwork.spotifyImageURL("http://i.scdn.co/image/abc") == nil)
        precondition(MediaArtwork.spotifyImageURL("https://attacker.example/i.scdn.co/image") == nil)
        precondition(MediaArtwork.spotifyImageURL("https://user:secret@i.scdn.co/image/abc") == nil)
        precondition(MediaArtwork.image(data: Data()) == nil)

        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.setColor(NSColor(calibratedRed: 0.55, green: 0.3, blue: 0.85, alpha: 1), atX: 0, y: 0)
        let png = bitmap.representation(using: .png, properties: [:])!
        precondition(MediaArtwork.image(data: png) != nil)
        print("MacNotch media artwork checks passed")
    }
}
