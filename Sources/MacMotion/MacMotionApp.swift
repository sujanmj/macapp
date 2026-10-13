import AppKit
import AVFoundation
import AVKit
import CoreGraphics
import UniformTypeIdentifiers

private final class WallpaperWindow: NSWindow {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private let playerView = AVPlayerView()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = true
        backgroundColor = .black
        ignoresMouseEvents = true
        hasShadow = false
        isReleasedWhenClosed = false
        player.isMuted = true
        player.actionAtItemEnd = .none
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspectFill
        playerView.frame = NSRect(origin: .zero, size: screen.frame.size)
        playerView.autoresizingMask = [.width, .height]
        contentView = playerView
        orderBack(nil)
    }

    func play(url: URL) {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }
}

@MainActor
private final class MacMotionApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var windows: [WallpaperWindow] = []
    private var wallpaperURL: URL?
    private var pausedByUser = false
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var powerObserver: NSObjectProtocol?
    private let savedPathKey = "MacMotion.videoPath"
    private let pauseOnLowPowerKey = "MacMotion.pauseOnLowPower"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◉"
        statusItem.button?.toolTip = "MacMotion Live Wallpaper"
        if UserDefaults.standard.object(forKey: pauseOnLowPowerKey) == nil {
            UserDefaults.standard.set(true, forKey: pauseOnLowPowerKey)
        }
        if let path = UserDefaults.standard.string(forKey: savedPathKey), FileManager.default.fileExists(atPath: path) {
            wallpaperURL = URL(fileURLWithPath: path)
        }
        installObservers()
        rebuildWindows()
        rebuildMenu()
        if wallpaperURL == nil { chooseVideo() }
    }

    private func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.windows.forEach { $0.player.pause() } }
        }
        wakeObserver = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshPlayback() }
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildWindows() }
        }
        powerObserver = NotificationCenter.default.addObserver(forName: Notification.Name("NSProcessInfoPowerStateDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshPlayback() }
        }
    }

    private func rebuildWindows() {
        windows.forEach { $0.stop(); $0.close() }
        windows = NSScreen.screens.map { WallpaperWindow(screen: $0) }
        refreshPlayback()
    }

    private func refreshPlayback() {
        guard let url = wallpaperURL, FileManager.default.fileExists(atPath: url.path) else { return }
        for window in windows {
            if window.player.currentItem == nil { window.play(url: url) }
            if pausedByUser || (UserDefaults.standard.bool(forKey: pauseOnLowPowerKey) && ProcessInfo.processInfo.isLowPowerModeEnabled) {
                window.player.pause()
            } else {
                window.player.play()
            }
        }
        rebuildMenu()
    }

    @objc private func chooseVideo() {
        let picker = NSOpenPanel()
        picker.title = "Choose an MP4 or MOV wallpaper"
        picker.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = false
        picker.begin { [weak self] result in
            guard result == .OK, let url = picker.url else { return }
            Task { @MainActor in
                guard let self else { return }
                self.wallpaperURL = url
                UserDefaults.standard.set(url.path, forKey: self.savedPathKey)
                self.pausedByUser = false
                self.windows.forEach { $0.play(url: url) }
                self.refreshPlayback()
            }
        }
    }

    @objc private func togglePause() {
        pausedByUser.toggle()
        refreshPlayback()
    }

    @objc private func toggleLowPowerPause() {
        let newValue = !UserDefaults.standard.bool(forKey: pauseOnLowPowerKey)
        UserDefaults.standard.set(newValue, forKey: pauseOnLowPowerKey)
        refreshPlayback()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func rebuildMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        let heading = NSMenuItem(title: wallpaperURL?.lastPathComponent ?? "No wallpaper selected", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())
        let choose = NSMenuItem(title: "Choose Video…", action: #selector(chooseVideo), keyEquivalent: "o")
        choose.target = self
        menu.addItem(choose)
        let toggle = NSMenuItem(title: pausedByUser ? "Resume Wallpaper" : "Pause Wallpaper", action: #selector(togglePause), keyEquivalent: "p")
        toggle.target = self
        menu.addItem(toggle)
        let lowPower = NSMenuItem(title: "Pause in Low Power Mode", action: #selector(toggleLowPowerPause), keyEquivalent: "")
        lowPower.target = self
        lowPower.state = UserDefaults.standard.bool(forKey: pauseOnLowPowerKey) ? .on : .off
        menu.addItem(lowPower)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MacMotion", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }
}

@main
private enum EntryPoint {
    static func main() {
        let app = NSApplication.shared
        let delegate = MacMotionApp()
        app.delegate = delegate
        app.run()
    }
}
