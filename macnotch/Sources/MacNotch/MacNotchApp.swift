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

struct ClipboardRecord: Identifiable {
    let id = UUID()
    let date = Date()
    let title: String
    let text: String?
    let payload: [[String: Data]]
}

@MainActor
final class NotchStore: ObservableObject {
    @Published var expanded = false
    @Published var cameraInset: CGFloat = 0
    @Published var compactWidth: CGFloat = 220
    @Published var expandedHeight: CGFloat = 248
    @Published var pinned = false
    @Published var hideInFullScreen = UserDefaults.standard.object(forKey: "hideMacNotchInFullScreen") as? Bool ?? true
    var resize: (() -> Void)?
    var applyFullScreenVisibility: ((Bool) -> Void)?
    @Published var clips: [ClipboardRecord] = []
    @Published var selected = Set<UUID>()
    @Published var clipboardEnabled = false
    @Published var musicEnabled = UserDefaults.standard.bool(forKey: "mediaConnected")
    @Published var player = UserDefaults.standard.string(forKey: "mediaPlayer") ?? "Spotify"
    @Published var position: Double = 0
    @Published var duration: Double = 0
    private var mediaBusy = false
    private let mediaQueue = DispatchQueue(label: "MacNotch.media", qos: .userInitiated)
    @Published var track = "Connect Music or Spotify"
    @Published var artist = ""
    @Published var playing = false
    @Published var musicMessage = ""
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
    private var hudID = UUID()
    let hardware = HardwareFeedback()
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
        if clipboardEnabled { sampleClipboard() }
        if musicEnabled { refreshMusic() }
        if let focusEnd {
            remaining = max(0, Int(ceil(focusEnd.timeIntervalSinceNow)))
            if remaining == 0 { self.focusEnd = nil; NSSound.beep(); message = "Focus session complete." }
        }
    }
    func setClipboard(_ enabled: Bool) {
        clipboardEnabled = enabled
        lastChange = NSPasteboard.general.changeCount
        if !enabled { clips.removeAll(); selected.removeAll() }
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
        if clips.count > 20 { clips.removeLast(clips.count - 20) }
        selected.formIntersection(Set(clips.map(\.id)))
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
        let source = "with timeout of 2 seconds\nif application \"\(chosen)\" is running then\n tell application \"\(chosen)\"\n if player state is stopped then return {\"Nothing playing\", \"\", \"stopped\", 0, 0}\n return {name of current track, artist of current track, player state as string, player position, \(durationExpression)}\n end tell\nelse\n return {\"Open \(chosen) to connect\", \"\", \"stopped\", 0, 0}\nend if\nend timeout"
        mediaQueue.async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            let failed = error != nil || result == nil
            let title = result?.atIndex(1)?.stringValue ?? "Nothing playing"
            let artist = result?.atIndex(2)?.stringValue ?? ""
            let playing = result?.atIndex(3)?.stringValue == "playing"
            let position = result?.atIndex(4)?.doubleValue ?? 0
            let duration = result?.atIndex(5)?.doubleValue ?? 0
            Task { @MainActor in
                guard let self else { return }
                self.mediaBusy = false
                guard self.player == chosen else { return }
                if failed { self.musicMessage = "Allow \(chosen) in Privacy & Security → Automation, then Connect again."; return }
                self.track = title; self.artist = artist; self.playing = playing
                self.duration = duration.isFinite ? max(0, duration) : 0
                self.position = position.isFinite ? min(self.duration, max(0, position)) : 0
                self.musicMessage = ""; self.resize?()
            }
        }
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
                    .overlay(LinearGradient(colors: [.cyan.opacity(0.16), .purple.opacity(0.13), .pink.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                Color.black
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: store.expanded ? 28 : 16,
                                          bottomTrailingRadius: store.expanded ? 28 : 16, topTrailingRadius: 5))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: store.expanded ? 28 : 14, bottomTrailingRadius: store.expanded ? 28 : 14, topTrailingRadius: 5).strokeBorder(.white.opacity(store.expanded ? 0.3 : 0.12), lineWidth: 0.7))
        .foregroundStyle(.primary)
        .preferredColorScheme(.light)
        .animation(reduceMotion ? nil : .smooth(duration: 0.32), value: store.expanded)
        .onHover { store.hover($0) }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: store.hardwareHUD != nil)
        .buttonStyle(NotchControlStyle())
    }
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 5) {
                ForEach(["Home", "Music", "Clipboard", "Gemini", "Focus", "Notes"], id: \.self) { item in
                    Button {
                        tab = item
                        store.expandedHeight = item == "Home" ? 248 : item == "Music" ? 260 : 340
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
                case "Clipboard": clipboard
                case "Gemini": gemini
                case "Focus": focus
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
        case "Clipboard": return "doc.on.clipboard"
        case "Gemini": return "sparkles"
        case "Focus": return "timer"
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
                .modifier(GlassCard(tint: .cyan))
            VStack(spacing: 8) {
                dashboardAction("Ask", detail: "Gemini", symbol: "sparkles", color: .cyan) { tab = "Gemini"; store.expandedHeight = 340; store.resize?() }
                dashboardAction("Notes", detail: "Catch a thought", symbol: "note.text", color: .orange) { tab = "Notes"; store.expandedHeight = 340; store.resize?() }
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
        switch section { case "Home": return .blue; case "Music": return .green; case "Clipboard": return .purple; case "Gemini": return .cyan; case "Focus": return .orange; default: return .pink }
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
            List(selection: $store.selected) {
                ForEach(store.clips) { clip in
                    HStack { Text(clip.title).font(.caption).lineLimit(2); Spacer(); Button("Copy") { store.copy(clip) } }.tag(clip.id)
                }
            }.frame(height: 120)
            HStack {
                Button("Combine Selected Text") { store.combine() }
                Button("Clear History") { store.clips.removeAll(); store.selected.removeAll() }
            }
            Text("20 clips · memory only · up to 2 MB each · marked concealed content excluded. Turn off to erase history.").font(.caption2).foregroundStyle(.secondary)
        }
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

struct NotchSettings: View {
    @ObservedObject var store: NotchStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("MacNotch Settings").font(.title2.bold())
                GeminiSettings()
                TextField("Gemini model", text: $store.model)
                Toggle("Volume and brightness feedback", isOn: Binding(get: { store.hardwareEnabled }, set: { store.setHardware($0) }))
                Toggle("Hide MacNotch in full-screen apps", isOn: Binding(get: { store.hideInFullScreen }, set: { store.setHideInFullScreen($0) }))
                Text("When enabled, the notch panel stays out of macOS full-screen spaces. The compact black pill remains close to the built-in camera notch size.").font(.caption)
                Text("Volume changes show the reported level when available. Brightness keys show direction only. Hardware-key visibility depends on macOS permissions/device; Apple’s own HUD remains enabled.").font(.caption)
                Button("Input Monitoring Settings") { openPrivacy("Privacy_ListenEvent") }
                Divider(); LoginToggle()
                Text("⌃⌥N expands/collapses the notch panel. Hover to expand; pin to keep it open. The panel unfolds from the top edge with smooth motion and respects Reduce Motion. The notch position follows the main screen when displays change. Siri opens Apple's own interface; it is not embedded. Media support is Music/Spotify, not private system-wide Now Playing APIs.").font(.caption)
            }.padding(20)
        }.frame(width: 480, height: 450)
    }
}

@MainActor
final class NotchDelegate: NSObject, NSApplicationDelegate {
    let store = NotchStore()
    let shortcut = GlobalShortcut()
    var window: FloatingWindow?
    var settings: FloatingWindow?
    var displayObserver: NSObjectProtocol?
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
        shortcut.action = { [weak self] in self?.toggle() }
        if !shortcut.register(key: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey)) { store.message = "Shortcut unavailable; use the menu bar." }
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position() }
        }
        position(animated: false); store.start(); window?.show(activate: false)
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
    func applicationWillTerminate(_ notification: Notification) { if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) } }
}

@main
struct MacNotchApp: App {
    @NSApplicationDelegateAdaptor(NotchDelegate.self) var delegate
    var body: some Scene {
        MenuBarExtra("MacNotch", systemImage: "capsule.fill") {
            Button("Show / Hide Panel") { delegate.toggle() }
            Button("Settings") { delegate.settings?.show() }
            Divider(); Button("Quit MacNotch") { NSApp.terminate(nil) }
        }
        Settings { NotchSettings(store: delegate.store) }
    }
}
