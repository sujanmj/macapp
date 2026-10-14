import AppKit
import Foundation
let args = CommandLine.arguments
precondition(args.count == 3)
let name = args[1]
let directory = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let symbols = ["MacShelf": "tray.2.fill", "MacSwitch": "rectangle.on.rectangle", "MacNotch": "capsule.fill", "MacVoice": "waveform"]
let color: NSColor = name == "MacVoice" ? .systemPurple : name == "MacNotch" ? .systemIndigo : name == "MacSwitch" ? .systemBlue : .systemTeal
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let shape = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 208, yRadius: 208)
NSGradient(starting: color, ending: NSColor(calibratedWhite: 0.05, alpha: 1))!.draw(in: shape, angle: -65)
if let symbol = NSImage(systemSymbolName: symbols[name] ?? "square", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 440, weight: .medium)) {
    symbol.isTemplate = false
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus(); symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set(); NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop); tinted.unlockFocus()
    tinted.draw(in: NSRect(x: 232, y: 252, width: 560, height: 520), from: .zero, operation: .sourceOver, fraction: 1)
}
image.unlockFocus()
var icons: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = base * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon-\(size).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
        icons.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": filename])
    }
}
try JSONSerialization.data(withJSONObject: ["images": icons, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
