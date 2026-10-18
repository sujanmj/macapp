import SwiftUI
import QuartzCore
import AppKit
import Carbon
import UniformTypeIdentifiers

struct PulseGlance: Decodable {
    let schema: Int
    let date: Date
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let cpu: Double?
    let topApp: String?
    let topBytes: UInt64?
}

struct TrayEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let path: String
    let addedAt: Date
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
    var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
    var size: Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        guard values?.isDirectory != true, let bytes = values?.fileSize else { return nil }
        return Int64(bytes)
    }
    init(url: URL) {
        self.id = UUID()
        self.path = url.standardizedFileURL.path
        self.addedAt = Date()
    }
}

@MainActor
final class NotchStore: ObservableObject {
    private static let pinnedClipboardURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.sujanmj.macnotch/PinnedClipboard.json")
    @Published var expanded = false
    @Published var cameraInset: CGFloat = 0
    @Published var compactWidth: CGFloat = 220
    @Published var expandedHeight: CGFloat = 248
    @Published var pinned = false
    @Published var hideInFullScreen = UserDefaults.standard.object(forKey: "hideMacNotchInFullScreen") as? Bool ?? true
    @Published var shakeToRevealShelf = UserDefaults.standard.object(forKey: "macNotchShakeToRevealShelf") as? Bool ?? true
    @Published var highlightPreset = UserDefaults.standard.string(forKey: "macNotchHighlightPreset") ?? "Electric Blue"
    var resize: (() -> Void)?
    var applyFullScreenVisibility: ((Bool) -> Void)?
    @Published var clips: [ClipboardRecord] = ClipboardPinStore.load(from: NotchStore.pinnedClipboardURL)
    @Published var selected = Set<UUID>()
    @Published var pinnedClipIDs = Set(ClipboardPinStore.load(from: NotchStore.pinnedClipboardURL).map(\.id))
    @Published var clipboardSearch = ""
    @Published var clipboardEnabled = false
    @Published var musicEnabled = UserDefaults.standard.bool(forKey: "mediaConnected")
    @Published var player = UserDefaults.standard.string(forKey: "mediaPlayer") ?? "Spotify"
    @Published var position: Double = 0
    @Published var duration: Double = 0
    private var mediaBusy = false
    private let mediaQueue = DispatchQueue(label: "MacNotch.media", qos: .userInitiated)
    @Published var track = "Connect Music or Spotify"
    @Published var artist = ""
    @Published var albumArtwork: NSImage?
    @Published var lyrics = ""
    @Published var lyricsExpanded = false
    @Published var playing = false
    @Published var musicMessage = ""
    private var artworkSourceKey: String?
    @Published var message = ""
    @Published var chat = ""
    @Published var answer = ""
    @Published var chatBusy = false
    @Published var model = "gemini-flash-latest"
    @Published var focusEnd: Date?
    @Published var remaining = 0
    @Published var pulse: PulseGlance?
    @Published var hardwareHUD: HardwareChange?
    @Published var hardwareEnabled = true
    @Published var activeApp = ""
    @Published var activeIcon: NSImage?
    @Published var inputTokens: Int?
    @Published var outputTokens: Int?
    @Published var sessionTokens = 0
    @Published var note = UserDefaults.standard.string(forKey: "quickNote") ?? ""
    @Published var trayFiles: [TrayEntry] = (try? JSONDecoder().decode([TrayEntry].self, from: UserDefaults.standard.data(forKey: "macNotchTrayFiles") ?? Data())) ?? []
    @Published var selectedTrayIDs = Set<UUID>()
    @Published var recentTrayDestinationPaths = UserDefaults.standard.stringArray(forKey: "macNotchRecentTrayDestinations") ?? []
    var recentTrayDestinations: [URL] {
        recentTrayDestinationPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }
    var trayURLsForSharing: [URL] {
        let entries = selectedTrayIDs.isEmpty ? trayFiles : trayFiles.filter { selectedTrayIDs.contains($0.id) }
        return entries.map(\.url).filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    @Published var metrics = MacMetrics()
    @Published var metricHistory: [SystemMetricPoint] = []
    private var metricHistoryStore = SystemMetricHistory()
    @Published var visibleMonitorWidgets = SystemMonitorWidget.restoring(UserDefaults.standard.stringArray(forKey: "macNotchVisibleMonitorWidgets"))
    @Published var trayDropTargeted = false
    var showFloatingTray: (() -> Void)?
    var showFloatingPlayer: (() -> Void)?
    var showFloatingStats: (() -> Void)?
    @Published var recorder = ScreenRecorderController()
    @Published var capture = ElementCaptureController()
    @Published var includeSystemAudio = UserDefaults.standard.object(forKey: "macNotchRecordSystemAudio") as? Bool ?? true
    @Published var includeMicrophone = UserDefaults.standard.object(forKey: "macNotchRecordMicrophone") as? Bool ?? false
    @Published var recording = false
    @Published var recordingSeconds = 0
    private let sampler = SystemSampler()
    private var lastMetricSample = Date.distantPast
    private var hudID = UUID()
    let hardware = HardwareFeedback()
    var highlightColor: Color {
        switch highlightPreset {
        case "Indigo": Color(red: 0.35, green: 0.34, blue: 1.0)
        case "Violet": Color(red: 0.58, green: 0.30, blue: 1.0)
        case "Magenta": Color(red: 0.86, green: 0.25, blue: 0.88)
        case "Rose": Color(red: 1.0, green: 0.30, blue: 0.55)
        case "Cyan": Color(red: 0.20, green: 0.82, blue: 1.0)
        case "Teal": Color(red: 0.12, green: 0.76, blue: 0.70)
        default: Color(red: 0.31, green: 0.40, blue: 1.0)
        }
    }
    private var appObserver: NSObjectProtocol?
    func setHardware(_ enabled: Bool) {
        hardwareEnabled = enabled
        if enabled { hardware.start() } else { hardware.stop(); hardwareHUD = nil; resize?() }
    }
    func setHideInFullScreen(_ hidden: Bool) {
        hideInFullScreen = hidden
        UserDefaults.standard.set(hidden, forKey: "hideMacNotchInFullScreen")
        applyFullScreenVisibility?(hidden)
    }
    func setShakeToRevealShelf(_ enabled: Bool) {
        shakeToRevealShelf = enabled
        UserDefaults.standard.set(enabled, forKey: "macNotchShakeToRevealShelf")
    }
    func setMonitorWidget(_ widget: SystemMonitorWidget, visible: Bool) {
        if visible { visibleMonitorWidgets.insert(widget) }
        else { visibleMonitorWidgets.remove(widget) }
        UserDefaults.standard.set(SystemMonitorWidget.saving(visibleMonitorWidgets), forKey: "macNotchVisibleMonitorWidgets")
    }
    func showHardware(_ change: HardwareChange) {
        guard hardwareEnabled else { return }
        hardwareHUD = change; hudID = UUID()
        let id = hudID
        resize?()
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard hudID == id else { return }
            hardwareHUD = nil; resize?()
        }
    }
    func updateActiveApp() {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else { return }
        activeApp = app.localizedName ?? ""; activeIcon = app.icon
        if !musicEnabled, ["Spotify", "Music"].contains(activeApp) { player = activeApp }
        resize?()
    }
    private var lastChange = NSPasteboard.general.changeCount
    private var ticks = 0
    private var timer: Timer?
    private var chatTask: Task<Void, Never>?
    private var chatID = UUID()
    private var hoverID = UUID()

    func hover(_ inside: Bool) {
        hoverID = UUID()
        let token = hoverID
        if inside {
            Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard hoverID == token else { return }
                expanded = true; resize?()
            }
        }
        else {
            Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                if hoverID == token && !pinned && !chatBusy { expanded = false; resize?() }
            }
        }
    }
    func start() {
        updateActiveApp()
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateActiveApp() }
        }
        hardware.changed = { [weak self] in self?.showHardware($0) }
        setHardware(hardwareEnabled)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func tick() {
        ticks += 1
        recording = recorder.isRecording
        recordingSeconds = recorder.elapsed
        if Date().timeIntervalSince(lastMetricSample) >= 2 {
            metrics = sampler.sample()
            metricHistoryStore.append(cpuPercent: metrics.cpuPercent,
                                      memoryPercent: Double(metrics.memoryUsed) / Double(max(1, metrics.memoryTotal)),
                                      date: metrics.sampledAt)
            metricHistory = metricHistoryStore.points
            lastMetricSample = metrics.sampledAt
        }
        if clipboardEnabled { sampleClipboard() }
        if musicEnabled { refreshMusic() }
        if let focusEnd {
            remaining = max(0, Int(ceil(focusEnd.timeIntervalSinceNow)))
            if remaining == 0 { self.focusEnd = nil; NSSound.beep(); message = "Focus session complete." }
        }
    }
    func addTrayURLs(_ urls: [URL]) {
        let existing = Set(trayFiles.map(\.path))
        let additions = urls.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
            .map { $0.standardizedFileURL }
            .filter { !existing.contains($0.path) }
            .map(TrayEntry.init(url:))
        guard !additions.isEmpty else { return }
        trayFiles.insert(contentsOf: additions, at: 0)
        persistTray()
        message = "Added \(additions.count) item\(additions.count == 1 ? "" : "s") to the file tray."
    }
    func removeTrayEntry(_ entry: TrayEntry) {
        trayFiles.removeAll { $0.id == entry.id }
        selectedTrayIDs.remove(entry.id)
        persistTray()
    }
    func clearTray() { trayFiles.removeAll(); selectedTrayIDs.removeAll(); persistTray() }
    private func persistTray() {
        if let data = try? JSONEncoder().encode(trayFiles) { UserDefaults.standard.set(data, forKey: "macNotchTrayFiles") }
    }
    func openTrayEntry(_ entry: TrayEntry) { NSWorkspace.shared.open(entry.url) }
    func revealTrayEntry(_ entry: TrayEntry) { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
    func createSmallerJPEGCopy(from sourceURL: URL) {
        let panel = NSSavePanel()
        panel.title = "Save Smaller JPEG Copy"
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-smaller.jpg"
        panel.allowedContentTypes = [.jpeg]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destinationURL = panel.url else { message = "Image export canceled."; return }
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else {
            message = "Choose a new file name; the original image will not be overwritten."
            return
        }
        message = "Creating a smaller JPEG copy…"
        Task.detached(priority: .userInitiated) { [store = self, sourceURL, destinationURL] in
            do {
                try ImageFileActions.createSmallerJPEG(from: sourceURL, to: destinationURL)
                await MainActor.run {
                    store.message = "Saved smaller JPEG copy as \(destinationURL.lastPathComponent). The original image is unchanged."
                    NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                }
            } catch {
                await MainActor.run { store.message = "Image export failed: \(error.localizedDescription)" }
            }
        }
    }
    func selectAllTrayFiles() {
        if !trayFiles.isEmpty && selectedTrayIDs.count == trayFiles.count { selectedTrayIDs.removeAll() }
        else { selectedTrayIDs = Set(trayFiles.map(\.id)) }
    }
    func copySelectedTrayFiles() {
        let urls = trayFiles.filter { selectedTrayIDs.contains($0.id) && FileManager.default.fileExists(atPath: $0.path) }.map { $0.url as NSURL }
        guard !urls.isEmpty else { message = "Select existing files in the tray first."; return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects(urls) else { message = "Could not copy these file references."; return }
        message = "Copied \(urls.count) file reference\(urls.count == 1 ? "" : "s"). Paste them into Finder or another app."
    }
    func sendTrayFilesToFolder() {
        let entries = selectedTrayIDs.isEmpty ? trayFiles : trayFiles.filter { selectedTrayIDs.contains($0.id) }
        let urls = entries.map(\.url).filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { message = "Add existing files to the tray before sending them to a folder."; return }
        let panel = NSOpenPanel()
        panel.title = "Copy Tray Items to Folder"
        panel.prompt = "Copy Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let destination = panel.url else { message = "Folder copy canceled."; return }
        copyTrayFiles(to: destination)
    }
    func copyTrayFiles(to destination: URL, remember: Bool = true) {
        let entries = selectedTrayIDs.isEmpty ? trayFiles : trayFiles.filter { selectedTrayIDs.contains($0.id) }
        let urls = entries.map(\.url).filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { message = "Add existing files to the tray before sending them to a folder."; return }
        guard (try? destination.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            message = "That destination folder is no longer available. Choose another folder."
            return
        }
        if remember {
            recentTrayDestinationPaths = RecentTrayDestinations.adding(destination, to: recentTrayDestinationPaths)
            UserDefaults.standard.set(recentTrayDestinationPaths, forKey: "macNotchRecentTrayDestinations")
        }
        message = "Copying \(urls.count) tray item\(urls.count == 1 ? "" : "s")…"
        Task.detached(priority: .userInitiated) { [store = self] in
            let result = TrayTransfer.copy(urls, to: destination)
            await MainActor.run {
                let names = result.copied.map(\.lastPathComponent)
                if result.failures.isEmpty {
                    store.message = "Copied \(names.count) item\(names.count == 1 ? "" : "s") to \(destination.lastPathComponent). Originals are unchanged."
                } else {
                    store.message = "Copied \(names.count); \(result.failures.count) could not be copied. Originals are unchanged."
                }
                if !result.copied.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(result.copied) }
            }
        }
    }
    func clearRecentTrayDestinations() {
        recentTrayDestinationPaths = []
        UserDefaults.standard.removeObject(forKey: "macNotchRecentTrayDestinations")
    }
    var trayPDFCount: Int {
        let entries = selectedTrayIDs.isEmpty ? trayFiles : trayFiles.filter { selectedTrayIDs.contains($0.id) }
        return entries.filter { $0.url.pathExtension.lowercased() == "pdf" && FileManager.default.fileExists(atPath: $0.path) }.count
    }
    func mergeTrayPDFs() {
        let entries = selectedTrayIDs.isEmpty ? trayFiles : trayFiles.filter { selectedTrayIDs.contains($0.id) }
        let sources = entries.map(\.url).filter { $0.pathExtension.lowercased() == "pdf" && FileManager.default.fileExists(atPath: $0.path) }
        guard sources.count >= 2 else { message = "Add or select at least two existing PDFs to merge."; return }
        let panel = NSSavePanel()
        panel.title = "Merge Tray PDFs"
        panel.nameFieldStringValue = "MacNotch-Merged.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { message = "PDF merge canceled."; return }
        message = "Merging \(sources.count) PDFs…"
        Task.detached(priority: .userInitiated) { [store = self] in
            do {
                let pages = try PDFFileActions.merge(sources, to: destination)
                await MainActor.run {
                    store.message = "Merged \(sources.count) PDFs (\(pages) pages) into \(destination.lastPathComponent). Originals are unchanged."
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            } catch {
                await MainActor.run { store.message = error.localizedDescription }
            }
        }
    }
    func zipTray() {
        let candidates = selectedTrayIDs.isEmpty ? trayFiles : trayFiles.filter { selectedTrayIDs.contains($0.id) }
        let urls = candidates.map(\.url).filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { message = "Add existing files to the tray before creating an archive."; return }
        let panel = NSSavePanel()
        panel.title = "Save MacNotch ZIP Archive"
        panel.nameFieldStringValue = "MacNotch-\(Int(Date().timeIntervalSince1970)).zip"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { message = "ZIP creation canceled."; return }
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent"] + urls.map(\.path) + [destination.path]
            do {
                try process.run(); process.waitUntilExit()
                await MainActor.run {
                    if process.terminationStatus == 0 {
                        self.message = "Archive saved to Desktop as \(destination.lastPathComponent)."
                        NSWorkspace.shared.activateFileViewerSelecting([destination])
                    } else { self.message = "Could not create the ZIP archive. Check available disk space and file access." }
                }
            } catch {
                await MainActor.run { self.message = "Could not create the ZIP archive: \(error.localizedDescription)" }
            }
        }
    }
    func setClipboard(_ enabled: Bool) {
        clipboardEnabled = enabled
        lastChange = NSPasteboard.general.changeCount
        if !enabled {
            clips.removeAll { !pinnedClipIDs.contains($0.id) }
            selected.formIntersection(Set(clips.map(\.id)))
        }
    }
    func sampleClipboard() {
        let board = NSPasteboard.general
        guard board.changeCount != lastChange else { return }
        lastChange = board.changeCount
        let privateTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType"]
        guard !privateTypes.contains(where: { board.types?.contains(NSPasteboard.PasteboardType($0)) == true }) else { return }
        let excluded = ["com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop", "com.apple.Passwords"]
        guard !excluded.contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") else { return }
        var payload: [[String: Data]] = []; var size = 0
        let allowed: [NSPasteboard.PasteboardType] = [.string, .png, .tiff, .fileURL, .URL, .rtf, .html]
        for item in board.pasteboardItems ?? [] {
            var values: [String: Data] = [:]
            for type in item.types where allowed.contains(type) {
                if let data = item.data(forType: type) { size += data.count; if size > 2_000_000 { return }; values[type.rawValue] = data }
            }
            if !values.isEmpty { payload.append(values) }
        }
        guard !payload.isEmpty else { return }
        let text = board.string(forType: .string)
        let title = text.map { String($0.prefix(120)).replacingOccurrences(of: "\n", with: " ↵ ") }
            ?? (board.types?.contains(.fileURL) == true ? "File references" : "Image or rich content")
        clips.insert(ClipboardRecord(title: title, text: text, payload: payload), at: 0)
        let sessionClips = clips.filter { !pinnedClipIDs.contains($0.id) }
        if sessionClips.count > 20 {
            let remove = Set(sessionClips.suffix(from: 20).map(\.id))
            clips.removeAll { remove.contains($0.id) }
        }
        selected.formIntersection(Set(clips.map(\.id)))
    }
    var visibleClipboardClips: [ClipboardRecord] {
        guard !clipboardSearch.isEmpty else { return clips }
        return clips.filter { $0.title.localizedCaseInsensitiveContains(clipboardSearch) || ($0.text?.localizedCaseInsensitiveContains(clipboardSearch) ?? false) }
    }
    func togglePinnedClip(_ clip: ClipboardRecord) {
        var pins = clips.filter { pinnedClipIDs.contains($0.id) }
        if pinnedClipIDs.contains(clip.id) { pins.removeAll { $0.id == clip.id } }
        else { pins.insert(clip, at: 0) }
        do {
            try ClipboardPinStore.save(pins, to: Self.pinnedClipboardURL)
            if pinnedClipIDs.contains(clip.id) {
                pinnedClipIDs.remove(clip.id)
                clips.removeAll { $0.id == clip.id }
                selected.remove(clip.id)
                message = "Clip unpinned and removed from this session."
            } else {
                pinnedClipIDs.insert(clip.id)
                message = "Pinned locally on this Mac."
            }
        } catch { message = error.localizedDescription }
    }
    func clearClipboardHistory() {
        clips.removeAll { !pinnedClipIDs.contains($0.id) }
        selected.formIntersection(Set(clips.map(\.id)))
        message = "Session history cleared. Pinned clips are kept."
    }
    func clearPinnedClips() {
        do {
            try ClipboardPinStore.save([], to: Self.pinnedClipboardURL)
            clips.removeAll { pinnedClipIDs.contains($0.id) }
            pinnedClipIDs.removeAll()
            selected.formIntersection(Set(clips.map(\.id)))
            message = "Pinned clips cleared from this Mac."
        } catch { message = error.localizedDescription }
    }
    func copy(_ clip: ClipboardRecord) {
        let board = NSPasteboard.general; board.clearContents()
        let items = clip.payload.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
            return item
        }
        board.writeObjects(items); lastChange = board.changeCount
        message = "Copied. Paste where you need it."
    }
    func combine() {
        let texts = clips.reversed().filter { selected.contains($0.id) }.compactMap(\.text)
        guard !texts.isEmpty else { message = "Select text clips to combine."; return }
        copyText(texts.joined(separator: "\n")); lastChange = NSPasteboard.general.changeCount
        message = "Combined \(texts.count) text clips in collection order."
    }
    var compactMedia: Bool { ["Spotify", "Music"].contains(activeApp) || (musicEnabled && playing && !compactAI) }
    var compactAI: Bool { activeApp == "ChatGPT" || activeApp == "Gemini" }
    func connectMusic() {
        musicEnabled = true
        UserDefaults.standard.set(true, forKey: "mediaConnected")
        UserDefaults.standard.set(player, forKey: "mediaPlayer")
        refreshMusic(); resize?()
    }
    func refreshMusic() {
        guard musicEnabled, !mediaBusy, ["Music", "Spotify"].contains(player) else { return }
        mediaBusy = true
        let chosen = player
        let durationExpression = chosen == "Spotify" ? "(duration of current track) / 1000" : "duration of current track"
        let details = chosen == "Spotify"
            ? "set coverURL to \"\"\n try\n set coverURL to artwork url of current track\n end try\n return {name of current track, artist of current track, player state as string, player position, \(durationExpression), coverURL}"
            : "set lyricText to \"\"\n set coverData to missing value\n try\n set lyricText to lyrics of current track\n end try\n try\n set coverData to raw data of artwork 1 of current track\n end try\n return {name of current track, artist of current track, player state as string, player position, \(durationExpression), lyricText, coverData}"
        let source = "with timeout of 3 seconds\nif application \"\(chosen)\" is running then\n tell application \"\(chosen)\"\n if player state is stopped then return {\"Nothing playing\", \"\", \"stopped\", 0, 0}\n \(details)\n end tell\nelse\n return {\"Open \(chosen) to connect\", \"\", \"stopped\", 0, 0}\nend if\nend timeout"
        mediaQueue.async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            let failed = error != nil || result == nil
            let title = result?.atIndex(1)?.stringValue ?? "Nothing playing"
            let artist = result?.atIndex(2)?.stringValue ?? ""
            let playing = result?.atIndex(3)?.stringValue == "playing"
            let position = result?.atIndex(4)?.doubleValue ?? 0
            let duration = result?.atIndex(5)?.doubleValue ?? 0
            let coverURL = chosen == "Spotify" ? result?.atIndex(6)?.stringValue : nil
            let lyrics = chosen == "Music" ? result?.atIndex(6)?.stringValue : nil
            let coverData = chosen == "Music" ? result?.atIndex(7)?.data : nil
            let coverImage = coverData.flatMap(MediaArtwork.image(data:))
            Task { @MainActor in
                guard let self else { return }
                self.mediaBusy = false
                guard self.player == chosen else { return }
                if failed { self.musicMessage = "Allow \(chosen) in Privacy & Security → Automation, then Connect again."; return }
                self.track = title; self.artist = artist; self.playing = playing
                self.duration = duration.isFinite ? max(0, duration) : 0
                self.position = position.isFinite ? min(self.duration, max(0, position)) : 0
                if chosen == "Music" {
                    self.artworkSourceKey = nil
                    self.albumArtwork = coverImage
                    self.lyrics = lyrics?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                } else {
                    self.lyrics = ""
                    self.loadSpotifyArtwork(coverURL, for: title)
                }
                self.musicMessage = ""; self.resize?()
            }
        }
    }
    private func loadSpotifyArtwork(_ value: String?, for trackTitle: String) {
        guard let url = MediaArtwork.spotifyImageURL(value) else {
            artworkSourceKey = nil; albumArtwork = nil; return
        }
        let key = url.absoluteString
        guard artworkSourceKey != key else { return }
        artworkSourceKey = key
        albumArtwork = nil
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let data, data.count <= 8 * 1024 * 1024,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = MediaArtwork.image(data: data) else { return }
            Task { @MainActor in
                guard let self, self.player == "Spotify", self.track == trackTitle,
                      self.artworkSourceKey == key else { return }
                self.albumArtwork = image
            }
        }.resume()
    }
    func seek(_ value: Double) {
        guard value.isFinite, duration > 0 else { return }
        let target = min(duration, max(0, value))
        let number = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), target)
        runMediaCommand("set player position to " + number)
    }
    func media(_ command: String) {
        guard ["playpause", "next track", "previous track"].contains(command) else { return }
        runMediaCommand(command)
    }
    private func runMediaCommand(_ command: String) {
        guard musicEnabled, ["Music", "Spotify"].contains(player) else { return }
        let chosen = player
        let source = "with timeout of 2 seconds\nif application \"\(chosen)\" is running then tell application \"\(chosen)\" to \(command)\nend timeout"
        mediaQueue.async { [weak self] in
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            let failed = error != nil
            Task { @MainActor in
                guard let self, self.player == chosen else { return }
                if failed { self.musicMessage = "Media command failed. Check Automation permission." }
                else { self.refreshMusic() }
            }
        }
    }
    func ask() {
        guard !chatBusy, !chat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatBusy = true; answer = ""
        let input = chat; let selectedModel = model
        chatID = UUID()
        let id = chatID
        chatTask = Task {
            defer { if chatID == id { chatBusy = false } }
            do { let response = try await GeminiClient.ask(input, model: selectedModel)
                if chatID == id {
                    answer = response.text; inputTokens = response.inputTokens; outputTokens = response.outputTokens
                    if let total = response.totalTokens { sessionTokens += total }
                }
            }
            catch { if chatID == id { answer = error is CancellationError ? "Cancelled." : error.localizedDescription } }
        }
    }
    func cancelChat() { chatID = UUID(); chatTask?.cancel(); chatBusy = false; answer = "Cancelled." }
    func clearChat() { chatID = UUID(); chatTask?.cancel(); chatBusy = false; chat = ""; answer = "" }
    func refreshPulse() {
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.sujanmj.macpulse/telemetry.json")
        if let data = try? Data(contentsOf: file), data.count < 65536,
           let snapshot = try? JSONDecoder().decode(PulseGlance.self, from: data), snapshot.schema == 1, snapshot.date <= Date().addingTimeInterval(60), snapshot.memoryUsed <= snapshot.memoryTotal {
            pulse = snapshot; message = Date().timeIntervalSince(snapshot.date) > 120 ? "Older MacPulse snapshot. Open MacPulse and refresh this glance." : "MacPulse snapshot loaded. Sample time is shown."
        } else { message = "Open MacPulse v1.1 to generate a local snapshot first." }
    }
    func startFocus() { focusEnd = Date().addingTimeInterval(25 * 60); remaining = 25 * 60 }
    func stopFocus() { focusEnd = nil; remaining = 0 }
    func openSiri() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Siri") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        } else { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!) }
    }
}

struct NotchView: View {
    @ObservedObject var store: NotchStore
    @State private var tab = "Home"
    @State private var scrubbing: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
            if store.cameraInset > 0 { Color.clear.frame(height: store.cameraInset) }
            ZStack(alignment: .top) {
                if let hud = store.hardwareHUD, !store.expanded {
                    HStack(spacing: 7) {
                        Image(systemName: hud.symbol).foregroundStyle(.white).font(.system(size: 10))
                        Text(hud.label).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        if let level = hud.level {
                            ProgressView(value: level).tint(.white).frame(width: 30)
                            Text("\(Int(level * 100))%").font(.system(size: 9, design: .monospaced))
                        }
                    }.frame(height: 30).transition(.opacity)
                } else if store.expanded {
                    expandedContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if store.recording {
                    HStack(spacing: 8) {
                        Circle().fill(.red).frame(width: 7, height: 7)
                        Text("REC \(clock(Double(store.recordingSeconds)))").font(.system(size: 9, weight: .bold, design: .monospaced))
                        Button { Task { await store.recorder.stop() } } label: { Image(systemName: "stop.fill").font(.system(size: 9)) }
                            .buttonStyle(.plain).help("Stop screen recording")
                        expandButton
                    }.frame(height: 30).foregroundStyle(.white).accessibilityLabel("Screen recording in progress")
                } else if store.compactMedia {
                    compactPlayer
                } else if store.compactAI {
                    HStack(spacing: 7) {
                        if let icon = store.activeIcon { Image(nsImage: icon).resizable().frame(width: 13, height: 13) }
                        Image(systemName: "sparkles").font(.system(size: 9)).foregroundStyle(.cyan)
                        Text("MacNotch").font(.system(size: 10, weight: .semibold))
                        expandButton
                    }.frame(height: 30).help("Open MacNotch for Gemini API usage. ChatGPT account allowance is not exposed by its desktop app.")
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: store.compactMedia ? "music.note" : "sparkle").font(.system(size: 10, weight: .semibold)).foregroundStyle(store.compactMedia ? .green : .cyan)
                        Text("MacNotch").font(.system(size: 10, weight: .semibold))
                        if store.focusEnd != nil { Text(String(format: "%02d:%02d", store.remaining / 60, store.remaining % 60)).font(.system(size: 9, design: .monospaced)) }
                        expandButton
                    }
                    .frame(height: 30)
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            if store.expanded {
                NotchGlass()
                    .overlay(Color.black.opacity(0.66))
                    .overlay(LinearGradient(colors: [Color(red: 0.08, green: 0.12, blue: 0.70).opacity(0.22), Color(red: 0.36, green: 0.10, blue: 0.76).opacity(0.20), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                Color.black
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: store.expanded ? 28 : 16,
                                          bottomTrailingRadius: store.expanded ? 28 : 16, topTrailingRadius: 5))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: store.expanded ? 28 : 14, bottomTrailingRadius: store.expanded ? 28 : 14, topTrailingRadius: 5).strokeBorder(.white.opacity(store.expanded ? 0.3 : 0.12), lineWidth: 0.7))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .smooth(duration: 0.32), value: store.expanded)
        .onHover { store.hover($0) }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: store.hardwareHUD != nil)
        .buttonStyle(NotchControlStyle(tint: store.highlightColor))
        .onDrop(of: [UTType.fileURL], isTargeted: $store.trayDropTargeted, perform: acceptDroppedFiles)
    }
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 5) {
                ForEach(["Home", "Music", "Tray", "Widgets", "Live", "Capture", "Record", "Clipboard", "Gemini", "Focus", "Events", "Notes"], id: \.self) { item in
                    Button {
                        tab = item
                        store.expandedHeight = item == "Home" ? 248 : item == "Music" ? 260 : item == "Tray" || item == "Widgets" || item == "Capture" ? 360 : item == "Events" ? 330 : 340
                        store.resize?()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: icon(item)).foregroundStyle(accent(item))
                            Text(item == "Clipboard" ? "Clips" : item).fontWeight(.medium)
                        }.font(.system(size: 10)).padding(.horizontal, 8).padding(.vertical, 7)
                            .background(tab == item ? accent(item).opacity(0.26) : accent(item).opacity(0.09), in: Capsule())
                    }.buttonStyle(.plain).foregroundStyle(.primary).help(item)
                }
                Spacer(minLength: 4)
                Button { store.pinned.toggle() } label: { Image(systemName: store.pinned ? "pin.fill" : "pin") }
                    .foregroundStyle(store.pinned ? .cyan : .gray).help("Keep open")
                Button { store.expanded = false; store.pinned = false; store.resize?() } label: { Image(systemName: "chevron.up") }
                    .help("Collapse")
            }.buttonStyle(.plain)
            Group {
                switch tab {
                case "Home": dashboard
                case "Music": media
                case "Tray": fileTray
                case "Widgets": widgets
                case "Live": liveActivities
                case "Capture": ElementCaptureView(capture: store.capture)
                case "Record": recordingControls
                case "Clipboard": clipboard
                case "Gemini": gemini
                case "Focus": focus
                case "Events": CalendarEventsView()
                default: notes
                }
            }.frame(maxWidth: .infinity, alignment: .topLeading)
                .id(tab).transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)
            if !store.message.isEmpty { Text(store.message).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
        }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

    }
    private func icon(_ name: String) -> String {
        switch name {
        case "Home": return "square.grid.2x2.fill"
        case "Music": return "music.note"
        case "Tray": return "tray.full.fill"
        case "Widgets": return "chart.xyaxis.line"
        case "Live": return "dot.radiowaves.left.and.right"
        case "Capture": return "viewfinder"
        case "Record": return "record.circle.fill"
        case "Clipboard": return "doc.on.clipboard"
        case "Gemini": return "sparkles"
        case "Focus": return "timer"
        case "Events": return "calendar"
        default: return "note.text"
        }
    }
    private var dashboard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.indigo.opacity(0.8), .purple.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: store.playing ? "waveform" : "music.note").font(.system(size: 26, weight: .light))
                    }.frame(width: 66, height: 66)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.musicEnabled ? store.track : "Your music, right here").font(.system(size: 13, weight: .semibold)).lineLimit(2)
                        Text(store.musicEnabled ? store.artist : "Music & Spotify").font(.system(size: 10)).foregroundStyle(.gray).lineLimit(1)
                    }
                }
                HStack(spacing: 22) {
                    if store.musicEnabled {
                        Button { store.media("previous track") } label: { Image(systemName: "backward.end.fill") }
                        Button { store.media("playpause") } label: { Image(systemName: store.playing ? "pause.fill" : "play.fill") }
                        Button { store.media("next track") } label: { Image(systemName: "forward.end.fill") }
                    } else {
                        Button("Connect player") { tab = "Music"; store.expandedHeight = 260; store.resize?() }
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.cyan)
                    }
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
            }.padding(14).frame(width: 250, height: 148, alignment: .topLeading)
                .modifier(GlassCard(tint: store.highlightColor))
            VStack(spacing: 8) {
                dashboardAction("Ask", detail: "Gemini", symbol: "sparkles", color: store.highlightColor) { tab = "Gemini"; store.expandedHeight = 340; store.resize?() }
                dashboardAction("Notes", detail: "Catch a thought", symbol: "note.text", color: store.highlightColor) { tab = "Notes"; store.expandedHeight = 340; store.resize?() }
            }.frame(width: 130)
            VStack(alignment: .leading, spacing: 12) {
                Text(Date(), format: .dateTime.weekday(.wide)).font(.system(size: 10)).foregroundStyle(.gray)
                Text(Date(), format: .dateTime.day().month(.abbreviated)).font(.system(size: 23, weight: .medium, design: .rounded))
                Divider().overlay(.white.opacity(0.12))
                Button {
                    if store.focusEnd == nil { store.startFocus() } else { store.stopFocus() }
                } label: {
                    Label(store.focusEnd == nil ? "Focus · 25 min" : String(format: "%02d:%02d · Stop", store.remaining / 60, store.remaining % 60), systemImage: "timer")
                        .font(.system(size: 11)).foregroundStyle(.mint)
                }.buttonStyle(.plain)
            }.padding(14).frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
                .modifier(GlassCard(tint: .orange))
        }
    }
    private func dashboardAction(_ title: String, detail: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 11, weight: .medium))
                    Text(detail).font(.system(size: 9)).foregroundStyle(.gray)
                }
                Spacer(minLength: 0)
            }.padding(12).frame(height: 70)
                .modifier(GlassCard(tint: color))
        }.buttonStyle(.plain)
    }
    private func accent(_ section: String) -> Color {
        switch section { case "Music": return .green; case "Focus": return .orange; case "Events": return .cyan; default: return store.highlightColor }
    }
    private var expandButton: some View {
        Button { store.expanded = true; store.pinned = true; store.resize?() } label: {
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
        }.buttonStyle(.plain).help("Expand notch").accessibilityLabel("Expand notch")
    }
    private var playbackButtons: some View {
        HStack(spacing: 16) {
            Button { store.media("previous track") } label: { Image(systemName: "backward.end.fill") }.help("Previous track")
            Button { store.media("playpause") } label: { Image(systemName: store.playing ? "pause.fill" : "play.fill") }.help("Play / Pause")
            Button { store.media("next track") } label: { Image(systemName: "forward.end.fill") }.help("Next track")
        }.buttonStyle(.plain).foregroundStyle(.green).disabled(!store.musicEnabled)
    }
    private var progressBar: some View {
        HStack(spacing: 8) {
            Text(clock(store.position)).font(.system(size: 9, design: .monospaced))
            Slider(value: Binding(get: { scrubbing ?? store.position }, set: { scrubbing = $0 }), in: 0...max(1, store.duration), onEditingChanged: { editing in
                if !editing, let target = scrubbing { store.seek(target); scrubbing = nil }
            }).tint(.green).disabled(!store.musicEnabled || store.duration <= 0)
                .accessibilityLabel("Playback position")
            Text(clock(store.duration)).font(.system(size: 9, design: .monospaced))
        }
    }
    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "—" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
    private var compactPlayer: some View {
        HStack(spacing: 7) {
            Image(systemName: store.playing ? "waveform" : "music.note").font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)
            Text("MacNotch").font(.system(size: 10, weight: .semibold))
            if store.musicEnabled { Image(systemName: store.playing ? "play.fill" : "pause.fill").font(.system(size: 8)).foregroundStyle(.green) }
            expandButton
        }.frame(height: 30).help(store.track)
    }
    private var media: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Player", selection: $store.player) { Text("Spotify").tag("Spotify"); Text("Music").tag("Music") }.frame(width: 220)
                    .onChange(of: store.player) { _, value in
                        UserDefaults.standard.set(value, forKey: "mediaPlayer")
                        store.position = 0; store.duration = 0; store.refreshMusic()
                    }
                Spacer()
                Button(store.musicEnabled ? "Refresh" : "Connect") { store.connectMusic() }
                Button { store.showFloatingPlayer?() } label: { Label("Float", systemImage: "macwindow") }
                    .help("Open the floating music player")
            }
            HStack(spacing: 16) {
                Image(systemName: "music.note").font(.system(size: 30)).foregroundStyle(.green)
                    .frame(width: 64, height: 64).modifier(GlassCard(tint: .green))
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.track).font(.title3.bold()).lineLimit(2)
                    Text(store.artist).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(); playbackButtons
            }
            progressBar
            if !store.musicMessage.isEmpty { Text(store.musicMessage).font(.caption2).foregroundStyle(.orange) }
        }.padding(16).modifier(GlassCard(tint: .green))
    }
    private var clipboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Capture clipboard history for this session", isOn: Binding(get: { store.clipboardEnabled }, set: { store.setClipboard($0) }))
            TextField("Search clips", text: $store.clipboardSearch)
                .textFieldStyle(.roundedBorder)
            List(selection: $store.selected) {
                ForEach(store.visibleClipboardClips) { clip in
                    HStack {
                        Text(clip.title).font(.caption).lineLimit(2)
                        Spacer()
                        Button { store.togglePinnedClip(clip) } label: {
                            Image(systemName: store.pinnedClipIDs.contains(clip.id) ? "pin.fill" : "pin")
                        }.buttonStyle(.plain).help(store.pinnedClipIDs.contains(clip.id) ? "Unpin and remove this clip" : "Pin this clip and save it on this Mac")
                        Button("Copy") { store.copy(clip) }
                    }.tag(clip.id)
                }
            }.frame(height: 120)
            HStack {
                Button("Combine Selected Text") { store.combine() }
                Button("Clear History") { store.clearClipboardHistory() }
                Button("Clear Pins") { store.clearPinnedClips() }
            }
            Text("Capture is opt-in and session-only (20 clips, 2 MB each). Pin saves selected clips in an unencrypted local file on this Mac (up to 100 clips / 8 MB). Clear History keeps pins; Clear Pins deletes them. Concealed clipboard items are excluded.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var fileTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("File Tray").font(.headline)
                    Text("Hold files from different folders here while you work.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.showFloatingTray?() } label: { Label("Float", systemImage: "macwindow.on.rectangle") }
                    .help("Open a floating file shelf")
                Button { chooseTrayFiles() } label: { Label("Add", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).tint(store.highlightColor)
            }
            if store.trayFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 24)).foregroundStyle(store.highlightColor)
                    Text(store.trayDropTargeted ? "Drop to add to your tray" : "Drop files here, or choose Add")
                        .font(.system(size: 12, weight: .medium))
                    Text("Files stay on this Mac. MacNotch stores their locations, not copies.").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 155)
                .background(store.highlightColor.opacity(store.trayDropTargeted ? 0.22 : 0.08), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(store.highlightColor.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(store.trayFiles) { entry in
                            HStack(spacing: 10) {
                                Toggle("Select \(entry.name)", isOn: Binding(
                                    get: { store.selectedTrayIDs.contains(entry.id) },
                                    set: { selected in
                                        if selected { store.selectedTrayIDs.insert(entry.id) }
                                        else { store.selectedTrayIDs.remove(entry.id) }
                                    }
                                )).labelsHidden().toggleStyle(.checkbox)
                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 16)).foregroundStyle(store.highlightColor).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                    Text(entry.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Folder")
                                        .font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Button { store.openTrayEntry(entry) } label: { Image(systemName: "arrow.up.forward.app") }
                                    .help("Open file")
                                Button { store.revealTrayEntry(entry) } label: { Image(systemName: "magnifyingglass") }
                                    .help("Show in Finder")
                                ShareLink(item: entry.url) { Image(systemName: "square.and.arrow.up") }
                                    .help("Share file")
                                Button { store.removeTrayEntry(entry) } label: { Image(systemName: "xmark.circle.fill") }
                                    .help("Remove from tray")
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                            .draggable(entry.url)
                            .contextMenu {
                                Button("Copy Path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(entry.path, forType: .string)
                                    store.message = "Copied file path."
                                }
                                Button("Show in Finder") { store.revealTrayEntry(entry) }
                                if UTType(filenameExtension: entry.url.pathExtension)?.conforms(to: .image) == true {
                                    Button("Create Smaller JPEG Copy…") { store.createSmallerJPEGCopy(from: entry.url) }
                                }
                                Button("Remove from Tray", role: .destructive) { store.removeTrayEntry(entry) }
                            }
                        }
                    }
                }.frame(height: 155)
            }
            HStack(spacing: 10) {
                Text("\(store.trayFiles.count) item\(store.trayFiles.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
                Button("Copy Selected") { store.copySelectedTrayFiles() }.disabled(store.selectedTrayIDs.isEmpty)
                Menu {
                    Button("Choose Folder…") { store.sendTrayFilesToFolder() }
                    if !store.recentTrayDestinations.isEmpty {
                        Divider()
                        ForEach(store.recentTrayDestinations, id: \.path) { destination in
                            Button(destination.lastPathComponent) { store.copyTrayFiles(to: destination) }
                                .help(destination.path)
                        }
                        Divider()
                        Button("Clear Recent Folders", role: .destructive) { store.clearRecentTrayDestinations() }
                    }
                } label: { Label("Send", systemImage: "folder") }
                    .help("Copy selected items, or all items, to a folder")
                    .disabled(store.trayFiles.isEmpty)
                Button { store.mergeTrayPDFs() } label: { Label("Merge", systemImage: "doc.on.doc") }
                    .help("Merge selected PDFs, or all tray PDFs, into a new PDF")
                    .disabled(store.trayPDFCount < 2)
                ShareLink(items: store.trayURLsForSharing) { Label(store.selectedTrayIDs.isEmpty ? "Share All" : "Share Selected", systemImage: "square.and.arrow.up") }
                    .disabled(store.trayURLsForSharing.isEmpty)
                Button(store.selectedTrayIDs.isEmpty ? "ZIP All" : "ZIP Selected") { store.zipTray() }.disabled(store.trayFiles.isEmpty)
                Button(store.selectedTrayIDs.count == store.trayFiles.count ? "Deselect All" : "Select All") { store.selectAllTrayFiles() }.disabled(store.trayFiles.isEmpty)
                Button("Clear") { store.clearTray() }.disabled(store.trayFiles.isEmpty)
            }.font(.system(size: 10))
            Text("Select files and copy their references to paste them into Finder or another app. Sharing, opening, and ZIP creation leave the originals in place.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var widgets: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("System Widgets").font(.headline)
                    Text("Local readings refresh about every two seconds.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.showFloatingStats?() } label: { Label("Float", systemImage: "macwindow") }
                    .help("Keep a compact system monitor above other windows")
                Text(store.metrics.sampledAt, style: .time).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                metricCard("CPU", value: String(format: "%.0f%%", store.metrics.cpuPercent), progress: store.metrics.cpuPercent / 100, symbol: "cpu", tint: .cyan)
                metricCard("Memory", value: "\(ByteCountFormatter.string(fromByteCount: Int64(clamping: store.metrics.memoryUsed), countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: Int64(clamping: store.metrics.memoryTotal), countStyle: .memory))", progress: Double(store.metrics.memoryUsed) / Double(max(1, store.metrics.memoryTotal)), symbol: "memorychip", tint: .purple)
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Network", systemImage: "wifi").font(.system(size: 10, weight: .medium)).foregroundStyle(.cyan)
                    Label("↓ \(speed(store.metrics.downloadBytesPerSecond))", systemImage: "arrow.down")
                    Label("↑ \(speed(store.metrics.uploadBytesPerSecond))", systemImage: "arrow.up")
                }.font(.system(size: 12, weight: .medium, design: .rounded)).frame(maxWidth: .infinity, minHeight: 78, alignment: .leading).padding(12).modifier(GlassCard(tint: .cyan))
                metricCard("Disk remaining", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: store.metrics.diskFree), countStyle: .file), progress: 1 - (Double(store.metrics.diskFree) / Double(max(1, store.metrics.diskTotal))), symbol: "internaldrive", tint: .mint)
            }
            if let battery = store.metrics.battery {
                HStack(spacing: 9) {
                    Image(systemName: battery.isCharging ? "battery.100percent.bolt" : "battery.100percent").foregroundStyle(.green)
                    Text("Battery").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    Text("\(battery.percent)%").font(.system(size: 11, weight: .semibold, design: .rounded))
                    ProgressView(value: Double(battery.percent), total: 100).tint(.green).frame(maxWidth: 90)
                    Text(battery.displayDetail).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 11).frame(height: 34).modifier(GlassCard(tint: .green))
            }
            HStack(spacing: 8) {
                Image(systemName: "memorychip.fill").foregroundStyle(.purple)
                Text("Top RAM app").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Text(store.metrics.topProcess ?? "Sampling…").font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 2)
                Text(store.metrics.topProcessBytes.map { ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory) } ?? "—")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.purple)
            }.padding(.horizontal, 12).frame(height: 36).modifier(GlassCard(tint: .purple))
            Text("CPU and memory use native macOS counters. The top app is sampled from process resident memory every 10 seconds. Network uses the primary en* adapter (typically Wi‑Fi or Ethernet). Disk free space is for your home volume.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var liveActivities: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Live Activities").font(.headline)
                    Text("A live view of the tasks MacNotch currently tracks.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("LIVE").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.green)
            }
            ScrollView {
                VStack(spacing: 7) {
                    activityRow("Music", detail: store.playing ? "\(store.track) · \(store.artist)" : (store.musicEnabled ? "Player connected · nothing playing" : "Not connected"), symbol: "music.note", tint: .green, active: store.playing)
                    activityRow("Focus", detail: store.focusEnd.map { _ in "\(store.remaining / 60):\(String(format: "%02d", store.remaining % 60)) remaining" } ?? "No timer running", symbol: "timer", tint: .orange, active: store.focusEnd != nil)
                    activityRow("File Tray", detail: store.trayFiles.isEmpty ? "Ready for files" : "\(store.trayFiles.count) file\(store.trayFiles.count == 1 ? "" : "s") waiting in your tray", symbol: "tray.full.fill", tint: store.highlightColor, active: !store.trayFiles.isEmpty)
                    activityRow("Screen recording", detail: store.recording ? "Recording · \(clock(Double(store.recordingSeconds)))" : "Not recording", symbol: "record.circle", tint: .red, active: store.recording)
                    activityRow("Frontmost app", detail: store.activeApp.isEmpty ? "Unavailable" : store.activeApp, symbol: "macwindow", tint: .cyan, active: true)
                }
            }.frame(height: 185)
            Text("Third-party calls, downloads, and system-wide activity feeds are not yet integrated. This view only reports state MacNotch can currently observe.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var recordingControls: some View {
        ScreenRecordingControls(recorder: store.recorder, includeSystemAudio: Binding(
            get: { store.includeSystemAudio },
            set: { value in store.includeSystemAudio = value; UserDefaults.standard.set(value, forKey: "macNotchRecordSystemAudio") }
        ), includeMicrophone: Binding(
            get: { store.includeMicrophone },
            set: { value in store.includeMicrophone = value; UserDefaults.standard.set(value, forKey: "macNotchRecordMicrophone") }
        ))
    }
    private func activityRow(_ title: String, detail: String, symbol: String, tint: Color, active: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 10, weight: .semibold))
                Text(detail).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Circle().fill(active ? tint : .gray.opacity(0.55)).frame(width: 6, height: 6)
        }.padding(.horizontal, 11).padding(.vertical, 9).modifier(GlassCard(tint: tint))
    }
    private func metricCard(_ title: String, value: String, progress: Double, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.system(size: 10, weight: .medium)).foregroundStyle(tint)
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
            ProgressView(value: min(1, max(0, progress))).tint(tint)
        }.frame(maxWidth: .infinity, minHeight: 78, alignment: .leading).padding(12).modifier(GlassCard(tint: tint))
    }
    private func speed(_ bytesPerSecond: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytesPerSecond), countStyle: .memory) + "/s"
    }
    private func chooseTrayFiles() {
        let panel = NSOpenPanel()
        panel.title = "Add files to MacNotch File Tray"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        if panel.runModal() == .OK { store.addTrayURLs(panel.urls) }
    }
    private func acceptDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        let type = UTType.fileURL.identifier
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(type) }
        guard !matching.isEmpty else { return false }
        for provider in matching {
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                let url = (item as? URL)
                    ?? (item as? NSURL).map { $0 as URL }
                    ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    ?? (item as? String).flatMap(URL.init(string:))
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async {
                    store.addTrayURLs([url])
                    store.expanded = true
                    store.pinned = true
                    store.resize?()
                }
            }
        }
        return true
    }
    private var gemini: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ask Gemini…", text: $store.chat, axis: .vertical).lineLimit(2...4)
            HStack {
                Button("Send") { store.ask() }.disabled(store.chatBusy || store.chat.isEmpty)
                if store.chatBusy { ProgressView().controlSize(.small); Button("Cancel") { store.cancelChat() } }
                Button("Clear") { store.clearChat() }
                Spacer(); Button("Open Gemini") { NSWorkspace.shared.open(URL(string: "https://gemini.google.com")!) }
            }
            ScrollView { Text(store.answer).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 100)
            HStack {
                Button("Copy Answer") { copyText(store.answer) }.disabled(store.answer.isEmpty)
                Spacer()
                if let i = store.inputTokens, let o = store.outputTokens {
                    Text("Last: \(i) in · \(o) out | Session: \(store.sessionTokens)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.cyan)
                }
            }
            Text("Usage is for Gemini API requests in this app. Account remaining: unavailable.").font(.caption2).foregroundStyle(.secondary)
            Text("Send shares your typed question with Google using your Gemini API key. Configure it in Settings.").font(.caption2)
        }
    }
    private var focus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.focusEnd == nil ? "A quiet space for one task." : "Focus time remaining").font(.headline)
            Text(String(format: "%02d:%02d", store.remaining / 60, store.remaining % 60)).font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit()
            HStack { Button("Start 25 Minutes") { store.startFocus() }; Button("Stop") { store.stopFocus() } }
            HStack {
                Button("MacPulse Glance") { store.refreshPulse() }
                Button("Review High-RAM Apps") {
                    if !NSWorkspace.shared.open(URL(string: "macpulse://clean")!) { store.message = "Install MacPulse to use RAM review." }
                }
            }
            if let pulse = store.pulse {
                Text("RAM \(ByteCountFormatter.string(fromByteCount: Int64(clamping: pulse.memoryUsed), countStyle: .binary)) · CPU \(pulse.cpu.map { String(format: "%.0f%%", $0) } ?? "—")").font(.caption)
                HStack { Text("Top app: \(pulse.topApp ?? "Unavailable")").lineLimit(1); Text(pulse.date, style: .time) }.font(.caption2)
            }
        }
    }
    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Quick note", systemImage: "note.text").font(.headline)
                Spacer()
                Button("Shortcuts") { NSWorkspace.shared.open(URL(string: "shortcuts://")!) }
                Button("Siri") { store.openSiri() }
            }
            TextEditor(text: $store.note).scrollContentBackground(.hidden).padding(12)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16)).frame(height: 180)
                .onChange(of: store.note) { _, value in UserDefaults.standard.set(String(value.prefix(50000)), forKey: "quickNote") }
            Text("Saved locally on this Mac.").font(.caption2).foregroundStyle(.secondary)
        }
    }

}

private struct FloatingPlayerView: View {
    @ObservedObject var store: NotchStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Now Playing", systemImage: "waveform").font(.headline)
                Spacer()
                Picker("Player", selection: $store.player) {
                    Text("Spotify").tag("Spotify")
                    Text("Music").tag("Music")
                }
                .frame(width: 150)
                .onChange(of: store.player) { _, value in
                    UserDefaults.standard.set(value, forKey: "mediaPlayer")
                    store.position = 0
                    store.duration = 0
                    store.refreshMusic()
                }
                Button {
                    store.lyricsExpanded.toggle()
                } label: {
                    Label(store.lyricsExpanded ? "Hide Lyrics" : "Lyrics", systemImage: "text.quote")
                }
                .disabled(store.player != "Music" || store.lyrics.isEmpty)
                .help("Lyrics are shown when Apple Music provides them for the current track")
            }
            HStack(spacing: 14) {
                Group {
                    if let artwork = store.albumArtwork {
                        Image(nsImage: artwork).resizable().scaledToFill()
                    } else {
                        Image(systemName: store.playing ? "waveform" : "music.note")
                            .font(.system(size: 30, weight: .medium)).foregroundStyle(.green)
                    }
                }
                .frame(width: 64, height: 64).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16)).clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.track).font(.title3.bold()).lineLimit(2)
                    Text(store.artist.isEmpty ? store.player : store.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 18) {
                    Button { store.media("previous track") } label: { Image(systemName: "backward.fill") }.help("Previous track")
                    Button { store.media("playpause") } label: {
                        Image(systemName: store.playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: Circle())
                    }.buttonStyle(.plain).help("Play or pause")
                    Button { store.media("next track") } label: { Image(systemName: "forward.fill") }.help("Next track")
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 4) {
                Slider(value: Binding(get: { store.position }, set: { store.seek($0) }), in: 0...max(1, store.duration))
                    .disabled(!store.musicEnabled || store.duration <= 0)
                HStack {
                    Text(clock(store.position))
                    Spacer()
                    Text(clock(store.duration))
                }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            if store.lyricsExpanded {
                ScrollView {
                    Text(store.lyrics).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
                .frame(height: 110).padding(10).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            if !store.musicMessage.isEmpty { Text(store.musicMessage).font(.caption2).foregroundStyle(.orange) }
            if !store.musicEnabled { Button("Connect to \(store.player)") { store.connectMusic() }.buttonStyle(.borderedProminent) }
        }
        .padding(18)
        .frame(minWidth: 400, minHeight: 215)
        .background(NotchGlass())
    }

    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "—" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

private struct FloatingStatsView: View {
    @ObservedObject var store: NotchStore

    private var metrics: MacMetrics { store.metrics }
    private var memoryFraction: Double { Double(metrics.memoryUsed) / Double(max(1, metrics.memoryTotal)) }
    private var diskFraction: Double { Double(metrics.diskFree) / Double(max(1, metrics.diskTotal)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "waveform.path.ecg").foregroundStyle(store.highlightColor)
                Text("System Monitor").font(.system(size: 13, weight: .semibold))
                Circle().fill(.green).frame(width: 6, height: 6)
                Spacer()
                Text(metrics.sampledAt, style: .time).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }
            let visible = store.visibleMonitorWidgets
            if visible.isEmpty {
                Label("All cards are hidden. Choose cards in Settings.", systemImage: "slider.horizontal.3")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70)
            }
            if visible.contains(.cpu) || visible.contains(.memory) {
                HStack(spacing: 8) {
                    if visible.contains(.cpu) {
                        statsTile("CPU", value: String(format: "%.0f%%", metrics.cpuPercent), fraction: metrics.cpuPercent / 100, symbol: "cpu", tint: .cyan)
                    }
                    if visible.contains(.memory) {
                        statsTile("RAM", value: "\(ByteCountFormatter.string(fromByteCount: Int64(clamping: metrics.memoryUsed), countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: Int64(clamping: metrics.memoryTotal), countStyle: .memory))", fraction: memoryFraction, symbol: "memorychip", tint: .purple)
                    }
                }
            }
            if visible.contains(.network) || visible.contains(.disk) {
                HStack(spacing: 8) {
                    if visible.contains(.network) {
                        VStack(alignment: .leading, spacing: 7) {
                            Label("Network", systemImage: "wifi").font(.system(size: 9, weight: .medium)).foregroundStyle(.cyan)
                            HStack(spacing: 10) {
                                Label("↓ \(speed(metrics.downloadBytesPerSecond))", systemImage: "arrow.down")
                                Label("↑ \(speed(metrics.uploadBytesPerSecond))", systemImage: "arrow.up")
                            }.font(.system(size: 10, weight: .medium, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                        }.frame(maxWidth: .infinity, minHeight: 55, alignment: .leading).padding(9).modifier(GlassCard(tint: .cyan))
                    }
                    if visible.contains(.disk) {
                        statsTile("Disk free", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: metrics.diskFree), countStyle: .file), fraction: diskFraction, symbol: "internaldrive", tint: .mint)
                    }
                }
            }
            if visible.contains(.topProcess) {
                HStack(spacing: 6) {
                    Image(systemName: "memorychip.fill").foregroundStyle(.purple)
                    Text("Top RAM").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    Text(metrics.topProcess ?? "Sampling…").font(.system(size: 10, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(metrics.topProcessBytes.map { ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory) } ?? "—")
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.purple)
                }.padding(.horizontal, 9).frame(height: 29).modifier(GlassCard(tint: .purple))
            }
            if visible.contains(.trends) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 12) {
                        Text("Last minute").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                        Text("CPU").foregroundStyle(.cyan)
                        Text("RAM").foregroundStyle(.purple)
                        Spacer()
                    }.font(.system(size: 8, weight: .semibold))
                    MetricTrendGraph(points: store.metricHistory)
                        .frame(height: 32)
                        .accessibilityLabel("CPU and memory usage history over the last minute")
                }.padding(.horizontal, 9).padding(.vertical, 6).modifier(GlassCard(tint: .cyan))
            }
            if visible.contains(.battery), let battery = metrics.battery {
                HStack(spacing: 7) {
                    Image(systemName: battery.isCharging ? "battery.100percent.bolt" : "battery.100percent").foregroundStyle(.green)
                    Text("Battery").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    Text("\(battery.percent)%").font(.system(size: 10, weight: .semibold, design: .rounded))
                    ProgressView(value: Double(battery.percent), total: 100).tint(.green).frame(maxWidth: 75)
                    Text(battery.displayDetail).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 9).frame(height: 27).modifier(GlassCard(tint: .green))
            }
        }
        .padding(12).frame(minWidth: 330, minHeight: 190)
        .background(NotchGlass())
    }

    private func statsTile(_ title: String, value: String, fraction: Double, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol).font(.system(size: 9, weight: .medium)).foregroundStyle(tint)
            Text(value).font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.72)
            ProgressView(value: min(1, max(0, fraction))).tint(tint)
        }.frame(maxWidth: .infinity, minHeight: 55, alignment: .leading).padding(9).modifier(GlassCard(tint: tint))
    }

    private func speed(_ bytesPerSecond: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytesPerSecond), countStyle: .memory) + "/s"
    }
}

private struct MetricTrendGraph: View {
    let points: [SystemMetricPoint]

    var body: some View {
        Canvas { context, size in
            guard points.count > 1, size.width > 0, size.height > 0 else { return }
            draw(points.map(\.cpuPercent), color: .cyan, in: &context, size: size)
            draw(points.map(\.memoryPercent), color: .purple, in: &context, size: size)
        }
    }

    private func draw(_ values: [Double], color: Color, in context: inout GraphicsContext, size: CGSize) {
        guard values.count > 1 else { return }
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let y = size.height - CGFloat(min(100, max(0, value))) / 100 * size.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }
}

private struct FloatingTrayView: View {
    @ObservedObject var store: NotchStore
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("File Shelf", systemImage: "tray.full.fill").font(.headline).foregroundStyle(store.highlightColor)
                Spacer()
                Button { chooseFiles() } label: { Label("Add", systemImage: "plus") }
            }
            Text("Keep files here while you work in other apps. Drag items out to hand them off.")
                .font(.caption).foregroundStyle(.secondary)
            if store.trayFiles.isEmpty {
                Label("Drop files here", systemImage: "arrow.down.to.line.compact")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(store.highlightColor.opacity(targeted ? 0.24 : 0.10), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(store.highlightColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.trayFiles) { entry in
                            HStack(spacing: 8) {
                                Toggle("Select \(entry.name)", isOn: Binding(
                                    get: { store.selectedTrayIDs.contains(entry.id) },
                                    set: { selected in
                                        if selected { store.selectedTrayIDs.insert(entry.id) }
                                        else { store.selectedTrayIDs.remove(entry.id) }
                                    }
                                )).labelsHidden().toggleStyle(.checkbox)
                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill").foregroundStyle(store.highlightColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name).lineLimit(1).font(.system(size: 11, weight: .medium))
                                    Text(entry.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Folder")
                                        .font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 2)
                                Button { store.openTrayEntry(entry) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open")
                                Button { store.removeTrayEntry(entry) } label: { Image(systemName: "xmark.circle") }.help("Remove")
                            }
                            .buttonStyle(.plain).padding(8)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                            .draggable(entry.url)
                            .contextMenu {
                                if UTType(filenameExtension: entry.url.pathExtension)?.conforms(to: .image) == true {
                                    Button("Create Smaller JPEG Copy…") { store.createSmallerJPEGCopy(from: entry.url) }
                                }
                                Button("Show in Finder") { store.revealTrayEntry(entry) }
                                Button("Remove from Tray", role: .destructive) { store.removeTrayEntry(entry) }
                            }
                        }
                    }
                }
                .frame(minHeight: 100, maxHeight: 260)
            }
            HStack(spacing: 8) {
                Text("\(store.trayFiles.count) items").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Copy Selected") { store.copySelectedTrayFiles() }.disabled(store.selectedTrayIDs.isEmpty)
                Menu {
                    Button("Choose Folder…") { store.sendTrayFilesToFolder() }
                    if !store.recentTrayDestinations.isEmpty {
                        Divider()
                        ForEach(store.recentTrayDestinations, id: \.path) { destination in
                            Button(destination.lastPathComponent) { store.copyTrayFiles(to: destination) }
                                .help(destination.path)
                        }
                        Divider()
                        Button("Clear Recent Folders", role: .destructive) { store.clearRecentTrayDestinations() }
                    }
                } label: { Label("Send", systemImage: "folder") }
                    .help("Copy selected items, or all items, to a folder")
                    .disabled(store.trayFiles.isEmpty)
                Button { store.mergeTrayPDFs() } label: { Label("Merge", systemImage: "doc.on.doc") }
                    .help("Merge selected PDFs, or all tray PDFs, into a new PDF")
                    .disabled(store.trayPDFCount < 2)
                ShareLink(items: store.trayURLsForSharing) { Label(store.selectedTrayIDs.isEmpty ? "Share All" : "Share Selected", systemImage: "square.and.arrow.up") }
                    .disabled(store.trayURLsForSharing.isEmpty)
                Button(store.selectedTrayIDs.count == store.trayFiles.count ? "Deselect All" : "Select All") { store.selectAllTrayFiles() }.disabled(store.trayFiles.isEmpty)
            }.font(.system(size: 10))
            Text(store.message).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(16).frame(width: 360)
        .background(NotchGlass().overlay(Color.black.opacity(0.68)))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(targeted ? store.highlightColor : .clear, lineWidth: 2))
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted, perform: acceptDroppedFiles)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Add files to MacNotch File Shelf"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { store.addTrayURLs(panel.urls) }
    }

    private func acceptDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL)
                    ?? (item as? NSURL).map { $0 as URL }
                    ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async { store.addTrayURLs([url]) }
            }
        }
        return true
    }
}

private struct CalendarEventsView: View {
    @StateObject private var controller = CalendarEventsController()
    @StateObject private var tasks = CalendarTasksController()
    @State private var section = "Events"
    @State private var showingReminderComposer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Calendar & Tasks").font(.headline)
                    Text(section == "Events" ? "Upcoming events · next 7 days" : "Incomplete reminders · next 30 days")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        if section == "Events" { await controller.loadUpcomingEvents() }
                        else { await tasks.loadUpcomingReminders() }
                    }
                } label: {
                    let busy = section == "Events" ? controller.busy : tasks.busy
                    let loaded = section == "Events" ? controller.hasLoaded : tasks.hasLoaded
                    Label(busy ? "Loading…" : (loaded ? "Refresh" : (section == "Events" ? "Load Events" : "Load Reminders")),
                          systemImage: section == "Events" ? "calendar.badge.clock" : "checklist")
                }.disabled(section == "Events" ? controller.busy : tasks.busy).buttonStyle(.borderedProminent).tint(.cyan)
                if section == "Reminders" {
                    Button { showingReminderComposer = true } label: { Label("New", systemImage: "plus") }
                        .help("Create a reminder")
                        .disabled(tasks.busy)
                }
            }
            Picker("Calendar section", selection: $section) {
                Text("Events").tag("Events")
                Text("Reminders").tag("Reminders")
            }.pickerStyle(.segmented).frame(maxWidth: 230)
            section == "Events" ? AnyView(eventList) : AnyView(reminderList)
            Text(section == "Events" ? controller.message : tasks.message)
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Privacy Settings") {
                openPrivacy(section == "Events" ? "Privacy_Calendars" : "Privacy_Reminders")
            }.font(.system(size: 10))
        }.padding(14).modifier(GlassCard(tint: .cyan))
            .sheet(isPresented: $showingReminderComposer) { NewReminderSheet(tasks: tasks) }
    }

    @ViewBuilder private var eventList: some View {
        if !controller.events.isEmpty {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(controller.events) { event in
                        HStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text(event.start.formatted(.dateTime.day())).font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text(event.start.formatted(.dateTime.month(.abbreviated))).font(.system(size: 8, weight: .medium)).foregroundStyle(.cyan)
                            }.frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                HStack(spacing: 5) {
                                    Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                                    Text("·")
                                    Text(event.calendarTitle).lineLimit(1)
                                }.font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }.padding(8).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }.frame(maxHeight: 220)
        } else if controller.hasLoaded {
            ContentUnavailableView("No upcoming events", systemImage: "calendar", description: Text("Nothing is scheduled in the next seven days."))
                .frame(height: 110)
        } else {
            ContentUnavailableView("Your calendar, at a glance", systemImage: "calendar", description: Text("Load events when you’re ready. Calendar access is requested only when you press the button."))
                .frame(height: 120)
        }
    }

    @ViewBuilder private var reminderList: some View {
        if !tasks.reminders.isEmpty {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(tasks.reminders) { reminder in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reminder.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                Text([reminder.dueDate?.formatted(date: .abbreviated, time: .omitted), reminder.listTitle].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Button { tasks.complete(reminder) } label: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                .buttonStyle(.plain).help("Mark reminder complete")
                        }.padding(8).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }.frame(maxHeight: 220)
        } else if tasks.hasLoaded {
            ContentUnavailableView("No incomplete reminders", systemImage: "checklist", description: Text("Nothing is due in the next 30 days."))
                .frame(height: 110)
        } else {
            ContentUnavailableView("Your tasks, at a glance", systemImage: "checklist", description: Text("Load reminders when you’re ready. Reminder access is requested only when you press the button."))
                .frame(height: 120)
        }
    }
}

private struct NewReminderSheet: View {
    @ObservedObject var tasks: CalendarTasksController
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Reminder").font(.headline)
            TextField("What do you need to remember?", text: $title).textFieldStyle(.roundedBorder)
            Toggle("Set a due date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }
            Text("The reminder is saved to your default Reminders list. Access is requested only when you save.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(tasks.message).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(saving ? "Saving…" : "Create Reminder") {
                    saving = true
                    Task {
                        if await tasks.create(title: title, dueDate: hasDueDate ? dueDate : nil) { dismiss() }
                        saving = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

struct ScreenRecordingControls: View {
    @ObservedObject var recorder: ScreenRecorderController
    @Binding var includeSystemAudio: Bool
    @Binding var includeMicrophone: Bool
    @StateObject private var transcriber = MeetingTranscriber()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recording & Meeting Notes").font(.headline)
                    Text("Record locally, then create an on-device transcript.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: recorder.isRecording ? "record.circle.fill" : "record.circle")
                    .font(.system(size: 22)).foregroundStyle(recorder.isRecording ? .red : .secondary)
            }
            if recorder.isRecording {
                Text(String(format: "%02d:%02d", recorder.elapsed / 60, recorder.elapsed % 60))
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Button { Task { await recorder.stop() } } label: { Label("Stop Recording", systemImage: "stop.fill") }
                    .buttonStyle(.borderedProminent).tint(.red)
            } else {
                HStack(spacing: 8) {
                    Picker("Capture", selection: $recorder.selectedWindowID) {
                        Text("Primary display").tag(Optional<CGWindowID>.none)
                        ForEach(recorder.availableWindows, id: \.windowID) { window in
                            let app = window.owningApplication?.applicationName ?? "App"
                            let title = window.title?.isEmpty == false ? window.title! : "Untitled window"
                            Text("\(app) — \(title)").tag(Optional(window.windowID))
                        }
                    }.labelsHidden().frame(maxWidth: .infinity)
                    Button { Task { await recorder.refreshWindows() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }.help("Load or refresh visible app windows; macOS may ask for Screen Recording access")
                }
                Toggle("Include system audio", isOn: $includeSystemAudio)
                if #available(macOS 15.0, *) { Toggle("Include microphone", isOn: $includeMicrophone) }
                Button { Task { await recorder.start(includeSystemAudio: includeSystemAudio, includeMicrophone: includeMicrophone, windowID: recorder.selectedWindowID) } } label: {
                    Label("Start Recording", systemImage: "record.circle")
                }.buttonStyle(.borderedProminent).tint(.red)
            }
            Text(recorder.message).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Recordings Folder") { recorder.openRecordingsFolder() }
                if let latest = recorder.latestRecording {
                    Button("Show Latest") { NSWorkspace.shared.activateFileViewerSelecting([latest]) }
                }
            }.font(.system(size: 10))
            if !recorder.isRecording {
                HStack(spacing: 8) {
                    Button {
                        if let latest = recorder.latestRecording { Task { await transcriber.transcribe(latest) } }
                    } label: {
                        Label(transcriber.isTranscribing ? "Transcribing…" : "Transcribe Latest", systemImage: "waveform")
                    }
                    .disabled(recorder.latestRecording == nil || transcriber.isTranscribing)
                    Button("Choose Recording…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.movie]
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url { Task { await transcriber.transcribe(url) } }
                    }.disabled(transcriber.isTranscribing)
                }.font(.system(size: 10))
                Text(transcriber.message).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let transcript = transcriber.transcriptURL {
                    HStack(spacing: 8) {
                        Button("Open Transcript") { NSWorkspace.shared.open(transcript) }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([transcript]) }
                    }.font(.system(size: 10))
                }
            }
            Text("Record the primary display or a single visible app window. MacNotch is excluded from display captures. Screen recording and optional microphone capture require macOS permissions; videos stay on this Mac.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(14).modifier(GlassCard(tint: .red))
    }
}

private struct ElementCaptureView: View {
    @ObservedObject var capture: ElementCaptureController
    @State private var tool = CapturePreviewTool.select

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Screen Capture & Text").font(.headline)
                    Text("Save a screenshot and copy text recognized from it.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "viewfinder").font(.system(size: 21)).foregroundStyle(.cyan)
            }
            HStack(spacing: 8) {
                Picker("Capture target", selection: $capture.target) {
                    Text("Entire display").tag(CaptureTarget.display)
                    ForEach(capture.windows) { window in
                        Text("\(window.appName): \(window.title)").tag(CaptureTarget.window(window.id))
                    }
                }.pickerStyle(.menu).frame(maxWidth: 390, alignment: .leading)
                Button("Refresh") { Task { await capture.refreshWindows() } }
                    .disabled(capture.busy)
            }.font(.system(size: 10))
            HStack(spacing: 8) {
                Button { Task { await capture.captureScreen() } } label: {
                    Label(capture.busy ? "Capturing…" : "Capture Screen", systemImage: "camera")
                }.buttonStyle(.borderedProminent).tint(.cyan).disabled(capture.busy)
                if capture.latestCapture != nil {
                    Button("Show Screenshot") { capture.showLatest() }
                }
                if !capture.recognizedText.isEmpty {
                    Button("Copy Text") { capture.copyText() }
                }
            }
            if let image = capture.image {
                Picker("Preview tool", selection: $tool) {
                    Text("Select area").tag(CapturePreviewTool.select)
                    Text("Markup").tag(CapturePreviewTool.markup)
                }.pickerStyle(.segmented).frame(maxWidth: 280)
                SelectableCaptureImage(image: image, selection: capture.selection,
                                       annotations: capture.annotations, tool: tool,
                                       onSelection: { capture.setSelection($0) },
                                       onAnnotation: { capture.addAnnotation($0) })
                    .frame(height: 112).clipShape(RoundedRectangle(cornerRadius: 9))
                if tool == .select, capture.selection != nil {
                    Button { Task { await capture.readSelection() } } label: {
                        Label("Save Crop & Read Text", systemImage: "text.viewfinder")
                    }.buttonStyle(.borderedProminent).tint(.cyan).disabled(capture.busy)
                } else if tool == .markup, !capture.annotations.isEmpty {
                    HStack {
                        Button("Undo Markup") { capture.undoAnnotation() }
                        Button { capture.saveAnnotatedCapture() } label: {
                            Label("Save Marked Copy", systemImage: "pencil.tip.crop.circle")
                        }.buttonStyle(.borderedProminent).tint(.cyan)
                    }
                }
            }
            if !capture.recognizedText.isEmpty {
                ScrollView {
                    Text(capture.recognizedText).font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(maxHeight: 92).padding(8).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            }
            Text(capture.message).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Capture a display or visible app window, crop an area to read it, or draw markup and save a separate copy. Images save locally to Pictures/MacNotch Captures. Screen Recording permission is required. OCR runs locally with Apple Vision.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(14).modifier(GlassCard(tint: .cyan))
            .task { await capture.refreshWindows() }
    }
}

private enum CapturePreviewTool: Hashable {
    case select
    case markup
}

private struct SelectableCaptureImage: View {
    let image: NSImage
    let selection: CGRect?
    let annotations: [[CGPoint]]
    let tool: CapturePreviewTool
    let onSelection: (CGRect?) -> Void
    let onAnnotation: ([CGPoint]) -> Void
    @State private var dragPoints: [CGPoint] = []

    var body: some View {
        GeometryReader { proxy in
            let imageSize = CGSize(width: max(1, image.size.width), height: max(1, image.size.height))
            let scale = min(proxy.size.width / imageSize.width, proxy.size.height / imageSize.height)
            let render = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let imageRect = CGRect(x: (proxy.size.width - render.width) / 2,
                                   y: (proxy.size.height - render.height) / 2,
                                   width: render.width, height: render.height)
            ZStack {
                Color.black.opacity(0.3)
                Image(nsImage: image).resizable().frame(width: render.width, height: render.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                if tool == .select,
                   let rect = selection.map({ displayRect($0, in: imageRect) }) ?? transientRect(in: imageRect) {
                    Rectangle().fill(Color.cyan.opacity(0.20))
                        .overlay(Rectangle().stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
                        .frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                Canvas { context, _ in
                    for points in annotations + (tool == .markup && dragPoints.count > 1 ? [dragPoints.map { normalized($0, in: imageRect) }] : []) {
                        guard let first = points.first else { continue }
                        var path = Path()
                        path.move(to: displayPoint(first, in: imageRect))
                        for point in points.dropFirst() { path.addLine(to: displayPoint(point, in: imageRect)) }
                        context.stroke(path, with: .color(.cyan), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }.allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3).onChanged { value in
                if dragPoints.isEmpty { dragPoints = [bounded(value.startLocation, to: imageRect)] }
                dragPoints.append(bounded(value.location, to: imageRect))
            }.onEnded { value in
                let points = dragPoints + [bounded(value.location, to: imageRect)]
                if tool == .select, let start = points.first, let end = points.last {
                    let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                                      width: abs(end.x - start.x), height: abs(end.y - start.y))
                    if rect.width >= 8, rect.height >= 8 {
                        onSelection(CGRect(x: (rect.minX - imageRect.minX) / imageRect.width,
                                           y: (rect.minY - imageRect.minY) / imageRect.height,
                                           width: rect.width / imageRect.width,
                                           height: rect.height / imageRect.height))
                    }
                } else if tool == .markup {
                    onAnnotation(points.map { normalized($0, in: imageRect) })
                }
                dragPoints = []
            })
        }
        .accessibilityLabel("Screenshot preview. Drag to select an area for text recognition.")
    }

    private func bounded(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX), y: min(max(point.y, rect.minY), rect.maxY))
    }

    private func normalized(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
    }

    private func displayPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }

    private func displayRect(_ normalized: CGRect, in rect: CGRect) -> CGRect {
        CGRect(x: rect.minX + normalized.minX * rect.width, y: rect.minY + normalized.minY * rect.height,
               width: normalized.width * rect.width, height: normalized.height * rect.height)
    }

    private func transientRect(in rect: CGRect) -> CGRect? {
        guard let start = dragPoints.first, let end = dragPoints.last else { return nil }
        return CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                      width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
}

struct NotchSettings: View {
    @ObservedObject var store: NotchStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("MacNotch Settings").font(.title2.bold())
                Picker("Highlight color", selection: $store.highlightPreset) {
                    ForEach(["Electric Blue", "Indigo", "Violet", "Magenta", "Rose", "Cyan", "Teal"], id: \.self) { color in Text(color).tag(color) }
                }
                .onChange(of: store.highlightPreset) { _, value in UserDefaults.standard.set(value, forKey: "macNotchHighlightPreset") }
                Text("Choose the accent that flows through the glass panel, buttons, and activity highlights.").font(.caption)
                GeminiSettings()
                TextField("Gemini model", text: $store.model)
                Toggle("Volume and brightness feedback", isOn: Binding(get: { store.hardwareEnabled }, set: { store.setHardware($0) }))
                Toggle("Hide MacNotch in full-screen apps", isOn: Binding(get: { store.hideInFullScreen }, set: { store.setHideInFullScreen($0) }))
                Toggle("Reveal file shelf when shaking a drag", isOn: Binding(get: { store.shakeToRevealShelf }, set: { store.setShakeToRevealShelf($0) }))
                Text("While carrying files, quickly reverse direction twice to bring the shelf beside the pointer. Drag tracking uses pointer movement only; files are read only when dropped.").font(.caption)
                Group {
                    Text("Floating System Monitor").font(.headline)
                    Text("Choose which cards stay in the compact floating monitor.").font(.caption).foregroundStyle(.secondary)
                    ForEach(SystemMonitorWidget.allCases) { widget in
                        Toggle(widget.title, isOn: Binding(
                            get: { store.visibleMonitorWidgets.contains(widget) },
                            set: { store.setMonitorWidget(widget, visible: $0) }
                        ))
                    }
                }
                Toggle("Capture system audio in screen recordings", isOn: Binding(get: { store.includeSystemAudio }, set: { value in store.includeSystemAudio = value; UserDefaults.standard.set(value, forKey: "macNotchRecordSystemAudio") }))
                if #available(macOS 15.0, *) {
                    Toggle("Capture microphone in screen recordings", isOn: Binding(get: { store.includeMicrophone }, set: { value in store.includeMicrophone = value; UserDefaults.standard.set(value, forKey: "macNotchRecordMicrophone") }))
                }
                Text("Screen recordings save to Movies/MacNotch Recordings. macOS will ask before screen or microphone capture starts.").font(.caption)
                Button("Screen Recording Privacy Settings") { openPrivacy("Privacy_ScreenCapture") }
                Button("Microphone Privacy Settings") { openPrivacy("Privacy_Microphone") }
                Text("When enabled, the notch panel stays out of macOS full-screen spaces. The compact black pill remains close to the built-in camera notch size.").font(.caption)
                Text("Volume changes show the reported level when available. Brightness keys show direction only. Hardware-key visibility depends on macOS permissions/device; Apple’s own HUD remains enabled.").font(.caption)
                Button("Input Monitoring Settings") { openPrivacy("Privacy_ListenEvent") }
                Divider(); LoginToggle()
                Text("⌃⌥N expands/collapses the notch panel; ⌃⌥F opens the floating file shelf; ⌃⌥W opens the floating system monitor; ⌃⌥M opens the music player. Hover to expand; pin to keep the notch panel open. Siri opens Apple's own interface; it is not embedded. Media support is Music/Spotify, not private system-wide Now Playing APIs.").font(.caption)
            }.padding(20)
        }.frame(width: 480, height: 450)
    }
}

@MainActor
final class NotchDelegate: NSObject, NSApplicationDelegate {
    let store = NotchStore()
    let shortcut = GlobalShortcut()
    let floatingTrayShortcut = GlobalShortcut()
    let floatingPlayerShortcut = GlobalShortcut()
    let floatingStatsShortcut = GlobalShortcut()
    var window: FloatingWindow?
    var settings: FloatingWindow?
    var floatingTray: FloatingWindow?
    var floatingPlayer: FloatingWindow?
    var floatingStats: FloatingWindow?
    var displayObserver: NSObjectProtocol?
    var dragMonitors: [Any] = []
    var dragShakeDetector = DragShakeDetector()
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = FloatingWindow(title: "MacNotch", size: NSSize(width: 500, height: 300), content: NotchView(store: store))
        window?.panel.styleMask = [.borderless, .nonactivatingPanel]
        window?.panel.isOpaque = false
        window?.panel.backgroundColor = .clear
        window?.panel.hasShadow = true
        window?.panel.isMovableByWindowBackground = false
        window?.panel.level = .statusBar
        store.applyFullScreenVisibility = { [weak self] hide in
            self?.window?.panel.collectionBehavior = hide ? [.canJoinAllSpaces] : [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        store.applyFullScreenVisibility?(store.hideInFullScreen)
        store.resize = { [weak self] in self?.position() }
        settings = FloatingWindow(title: "MacNotch Settings", size: NSSize(width: 500, height: 440), content: NotchSettings(store: store))
        floatingTray = FloatingWindow(title: "MacNotch File Shelf", size: NSSize(width: 392, height: 360), content: FloatingTrayView(store: store))
        floatingPlayer = FloatingWindow(title: "MacNotch Player", size: NSSize(width: 460, height: 260), content: FloatingPlayerView(store: store))
        floatingStats = FloatingWindow(title: "MacNotch System Monitor", size: NSSize(width: 370, height: 230), content: FloatingStatsView(store: store))
        _ = floatingTray?.panel.setFrameAutosaveName("MacNotchFloatingFileShelf")
        _ = floatingPlayer?.panel.setFrameAutosaveName("MacNotchFloatingPlayer")
        _ = floatingStats?.panel.setFrameAutosaveName("MacNotchFloatingSystemMonitor")
        store.showFloatingTray = { [weak self] in self?.showFloatingTray() }
        store.showFloatingPlayer = { [weak self] in self?.showFloatingPlayer() }
        store.showFloatingStats = { [weak self] in self?.showFloatingStats() }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in self?.handleFileDrag(at: point) }
        }) { dragMonitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] event in
            let point = NSEvent.mouseLocation
            Task { @MainActor in self?.handleFileDrag(at: point) }
            return event
        }) { dragMonitors.append(monitor) }
        shortcut.action = { [weak self] in self?.toggle() }
        if !shortcut.register(key: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey)) { store.message = "Shortcut unavailable; use the menu bar." }
        floatingTrayShortcut.action = { [weak self] in self?.showFloatingTray() }
        if !floatingTrayShortcut.register(key: UInt32(kVK_ANSI_F), modifiers: UInt32(controlKey | optionKey)) {
            store.message = "Floating shelf shortcut unavailable; use the menu bar or File Tray."
        }
        floatingPlayerShortcut.action = { [weak self] in self?.showFloatingPlayer() }
        if !floatingPlayerShortcut.register(key: UInt32(kVK_ANSI_M), modifiers: UInt32(controlKey | optionKey)) {
            store.message = "Floating player shortcut unavailable; use the Music tab."
        }
        floatingStatsShortcut.action = { [weak self] in self?.showFloatingStats() }
        if !floatingStatsShortcut.register(key: UInt32(kVK_ANSI_W), modifiers: UInt32(controlKey | optionKey)) {
            store.message = "System monitor shortcut unavailable; use the menu bar or Widgets tab."
        }
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position() }
        }
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        position(animated: false); store.start(); window?.show(activate: false)
    }
    @objc func addFilesToTray(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ?? [])
            .compactMap { $0 as? URL }
            .filter(\.isFileURL)
        guard !urls.isEmpty else {
            error.pointee = "No file references were provided." as NSString
            return
        }
        store.addTrayURLs(urls)
        store.expanded = true
        store.pinned = true
        position()
        window?.panel.orderFrontRegardless()
    }
    func position(animated: Bool = true) {
        guard let screen = window?.panel.screen ?? NSScreen.main ?? NSScreen.screens.first,
              let panel = window?.panel else { return }
        let inset = screen.safeAreaInsets.top
        store.cameraInset = inset
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let cameraNotchWidth = max(0, right.minX - left.maxX)
            store.compactWidth = min(250, max(176, cameraNotchWidth + 24))
        } else { store.compactWidth = 184 }
        let size = NSSize(width: store.expanded ? min(700, screen.frame.width - 40) : store.compactWidth,
                          height: (store.expanded ? store.expandedHeight : 30) + inset)
        let frame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                           width: size.width, height: size.height)
        guard panel.frame != frame else { return }
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
    }
    func toggle() {
        store.expanded.toggle(); store.pinned = store.expanded; position()
        window?.panel.orderFrontRegardless()
    }
    func showFloatingTray() { floatingTray?.show() }
    func showFloatingPlayer() { floatingPlayer?.show() }
    func showFloatingStats() { floatingStats?.show() }
    func handleFileDrag(at point: CGPoint) {
        guard store.shakeToRevealShelf else { dragShakeDetector.reset(); return }
        if floatingTray?.panel.frame.insetBy(dx: -18, dy: -18).contains(point) == true {
            dragShakeDetector.reset()
            return
        }
        if dragShakeDetector.update(point: point, time: ProcessInfo.processInfo.systemUptime) {
            floatingTray?.show(near: point)
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        dragMonitors.forEach { NSEvent.removeMonitor($0) }
    }
}

@main
struct MacNotchApp: App {
    @NSApplicationDelegateAdaptor(NotchDelegate.self) var delegate
    var body: some Scene {
        MenuBarExtra("MacNotch", systemImage: "capsule.fill") {
            Button("Show / Hide Panel") { delegate.toggle() }
            Button("Floating File Shelf   ⌃⌥F") { delegate.showFloatingTray() }
            Button("Floating Player   ⌃⌥M") { delegate.showFloatingPlayer() }
            Button("System Monitor   ⌃⌥W") { delegate.showFloatingStats() }
            Button("Settings") { delegate.settings?.show() }
            Divider(); Button("Quit MacNotch") { NSApp.terminate(nil) }
        }
        Settings { NotchSettings(store: delegate.store) }
    }
}
