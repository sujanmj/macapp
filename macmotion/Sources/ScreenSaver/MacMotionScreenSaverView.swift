import AppKit
import AVFoundation
import QuartzCore
import ScreenSaver

/// Loaded by the macOS Screen Saver engine when the user selects MacMotion
/// under System Settings → Wallpaper → Screen Saver… → Custom.
@objc(MacMotionScreenSaverView)
final class MacMotionScreenSaverView: ScreenSaverView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private let videoLayer = AVPlayerLayer()
    private let placeholder = NSTextField(labelWithString: "Open MacMotion and choose a video to use as your screen saver")
    private var loadedPath: String?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        autoresizesSubviews = true

        player.isMuted = true
        player.actionAtItemEnd = .none
        videoLayer.player = player
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.frame = bounds
        layer?.addSublayer(videoLayer)

        placeholder.alignment = .center
        placeholder.textColor = .white
        placeholder.font = .systemFont(ofSize: isPreview ? 12 : 22, weight: .medium)
        placeholder.maximumNumberOfLines = 3
        placeholder.lineBreakMode = .byWordWrapping
        placeholder.frame = bounds.insetBy(dx: 18, dy: 18)
        placeholder.autoresizingMask = [.width, .height]
        addSubview(placeholder)

        animationTimeInterval = 1
        loadSelectedVideo()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        videoLayer.frame = bounds
    }

    private func loadSelectedVideo() {
        // The menu-bar app stores its selected path in its own preferences domain.
        let path = UserDefaults(suiteName: "com.macmotion.wallpaper")?
            .string(forKey: "MacMotion.videoPath")
        guard let path, FileManager.default.fileExists(atPath: path) else {
            placeholder.isHidden = false
            return
        }
        if loadedPath == path, looper != nil { return }
        loadedPath = path
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        let url = URL(fileURLWithPath: path)
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        placeholder.isHidden = true
    }

    override func startAnimation() {
        super.startAnimation()
        loadSelectedVideo()
        player.play()
    }

    override func stopAnimation() {
        player.pause()
        super.stopAnimation()
    }

    override func animateOneFrame() {
        // AVFoundation renders frames independently; no repaint required.
    }

    deinit {
        player.pause()
        looper?.disableLooping()
        player.removeAllItems()
    }
}
