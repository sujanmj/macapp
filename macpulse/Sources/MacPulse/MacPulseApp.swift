import AppKit
import SwiftUI

enum PulsePage: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case memory = "Memory Cleaner"
    case storage = "Storage Analyzer"
    case cleanup = "Safe Cleanup"
    case duplicates = "Duplicates"
    case vpn = "VPN"
    case tools = "More Tools"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .memory: return "memorychip"
        case .storage: return "externaldrive"
        case .cleanup: return "trash.slash"
        case .duplicates: return "doc.on.doc"
        case .vpn: return "network.badge.shield.half.filled"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

@MainActor
final class PulseStore: ObservableObject {
    @Published var stats = SystemSnapshot.read()
    @Published var cleanup: [CleanupCandidate] = []
    @Published var storageResult: StorageScanResult?
    @Published var selectedStoragePaths: Set<String> = []

    @Published var memoryApps: [RunningAppMemory] = []
    @Published var warpStatus: String?
    @Published var duplicates: [DuplicateGroup] = []
    @Published var vpn: [VPNService] = []
    @Published var busy = false
    @Published var message = ""
    @Published var requestedPage: PulsePage?
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func refresh() {
        stats = SystemSnapshot.read()
        vpn = VPNControl.list()
        memoryApps = MemoryTools.runningApps()
        if VPNControl.warpCLI != nil {
            Task.detached(priority: .utility) {
                let status = VPNControl.warpStatus()
                await MainActor.run { self.warpStatus = status }
            }
        } else {
            warpStatus = nil
        }
    }
    func route(_ url: URL) {
        guard url.scheme?.lowercased() == "macpulse" else { return }
        switch url.host?.lowercased() {
        case "clean": requestedPage = .memory; refresh()
        case "vpn": requestedPage = .vpn; refresh()
        case "duplicates": requestedPage = .duplicates
        case "storage": requestedPage = .storage
        default: requestedPage = .dashboard
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func chooseStorageFolder() {
        let dialog = NSOpenPanel()
        dialog.title = "Choose a folder to analyze without changing anything"
        dialog.prompt = "Analyze Folder"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = false
        guard dialog.runModal() == .OK, let folder = dialog.url else { return }
        analyze(folder: folder)
    }

    func analyze(folder: URL) {
        busy = true
        storageResult = nil
        selectedStoragePaths.removeAll()
        message = "Scanning \(folder.lastPathComponent) — read-only, up to 20,000 entries…"
        Task.detached(priority: .utility) {
            let result = StorageAnalyzer.scan(folder)
            await MainActor.run {
                self.storageResult = result
                self.busy = false
                self.message = "Scanned \(result.files.count) regular files" +
                    (result.wasLimited ? " (20,000-entry safety limit reached)." : ".")
            }
        }
    }

    func toggleStorageFile(_ entry: StorageEntry) {
        if selectedStoragePaths.contains(entry.id) {
            selectedStoragePaths.remove(entry.id)
        } else {
            selectedStoragePaths.insert(entry.id)
        }
    }

    func trashSelectedStorage() {
        guard let report = storageResult else { return }
        let chosen = report.files.filter { selectedStoragePaths.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let total = chosen.reduce(UInt64(0)) { $0 + $1.size }
        let warning = NSAlert()
        warning.alertStyle = .warning
        warning.messageText = "Move \(chosen.count) selected files to Trash?"
        warning.informativeText = "Selected: \(SystemSnapshot.bytes(total)) from \(report.folder.path). Files will be rechecked for path and size before moving. This may affect files used by other apps. You can restore them from Trash."
        warning.addButton(withTitle: "Move Selected Files to Trash")
        warning.addButton(withTitle: "Cancel")
        guard warning.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        StorageAnalyzer.moveToTrash(chosen, root: report.folder) { result in
            self.busy = false
            self.message = result
            self.analyze(folder: report.folder)
        }
    }

    func scanLogs() {
        busy = true
        Task.detached(priority: .utility) {
            let result = SafeCleanup.scan()
            await MainActor.run {
                self.cleanup = result
                self.busy = false
                self.message = "Found \(result.count) old user log files. Review before cleaning."
            }
        }
    }
    func trashOldLogs() {
        guard !cleanup.isEmpty else { return }
        let bytes = cleanup.reduce(UInt64(0)) { $0 + $1.size }
        let warning = NSAlert()
        warning.alertStyle = .warning
        warning.messageText = "Move \(cleanup.count) old log files to Trash?"
        warning.informativeText = "Total: \(SystemSnapshot.bytes(bytes)). Only .log/.txt files older than 14 days in ~/Library/Logs are affected. No permanent deletion. Some apps may recreate logs."
        warning.addButton(withTitle: "Move to Trash")
        warning.addButton(withTitle: "Cancel")
        guard warning.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        SafeCleanup.trash(cleanup) { outcome in
            self.busy = false
            self.message = outcome
            self.scanLogs()
            self.refresh()
        }
    }
    func chooseDuplicatesFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.canCreateDirectories = false
        picker.prompt = "Scan Read-Only"
        guard picker.runModal() == .OK, let folder = picker.url else { return }
        busy = true
        message = "Scanning \(folder.lastPathComponent) for exact duplicate files..."
        Task.detached(priority: .utility) {
            let result = DuplicateFinder.scan(folder)
            await MainActor.run {
                self.duplicates = result
                self.busy = false
                self.message = "Found \(result.count) exact duplicate groups. No files were deleted."
            }
        }
    }
    func requestQuit(_ app: RunningAppMemory) {
        let alert = NSAlert()
        alert.messageText = "Ask \(app.name) to quit?"
        alert.informativeText = "This requests a normal quit. The app may ask you to save documents. MacPulse will not force-quit or kill any process."
        alert.addButton(withTitle: "Request Quit")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let succeeded = MemoryTools.requestQuit(app)
        message = succeeded ? "Requested a normal quit for \(app.name)." : "Could not request \(app.name) to quit."
        refresh()
    }

    func toggleWarp() {
        guard let status = warpStatus else { return }
        busy = true
        let connected = VPNControl.warpConnected(status)
        Task.detached(priority: .userInitiated) {
            let result: String
            do {
                try VPNControl.toggleWARP(connected: connected)
                result = "Cloudflare WARP request sent. Verify the connection in Cloudflare WARP."
            } catch {
                result = "WARP control failed: \(error.localizedDescription)"
            }
            await MainActor.run {
                self.busy = false
                self.message = result
                self.refresh()
            }
        }
    }

    func toggleVPN(_ service: VPNService) {
        busy = true
        Task.detached(priority: .userInitiated) {
            let result: String
            do {
                try VPNControl.toggle(service)
                result = "Requested \(service.connected ? "disconnect" : "connect") for \(service.name). Confirm status in macOS."
            } catch {
                result = "VPN control failed: \(error.localizedDescription)"
            }
            await MainActor.run {
                self.busy = false
                self.message = result
                self.refresh()
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let used: UInt64
    let total: UInt64
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline)
            Text(SystemSnapshot.bytes(used))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("of \(SystemSnapshot.bytes(total))")
                .font(.caption).foregroundStyle(.secondary)
            ProgressView(value: total > 0 ? Double(used) / Double(total) : 0)
                .tint(.cyan)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct MainView: View {
    @ObservedObject var store: PulseStore
    @State private var selected: PulsePage = .dashboard
    var body: some View {
        NavigationSplitView {
            List(PulsePage.allCases, selection: $selected) { page in
                Label(page.rawValue, systemImage: page.icon)
                    .tag(page)
            }
            .navigationTitle("MacPulse")
            .frame(minWidth: 185)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(selected.rawValue).font(.largeTitle.bold())
                        Spacer()
                        Button { store.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    }
                    switch selected {
                    case .dashboard: dashboard
                    case .memory: memory
                    case .storage: storage
                    case .cleanup: cleanup
                    case .duplicates: duplicates
                    case .vpn: vpn
                    case .tools: tools
                    }
                    if !store.message.isEmpty {
                        Text(store.message).font(.callout).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 850, minHeight: 560)
        .onChange(of: store.requestedPage) { newValue in
            if let newValue { selected = newValue }
        }
        .onOpenURL(perform: store.route)
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                StatTile(title: "Memory in use · estimated", used: store.stats.usedMemory,
                         total: store.stats.totalMemory, symbol: "memorychip")
                StatTile(title: "Disk space used", used: store.stats.totalDisk - store.stats.freeDisk,
                         total: store.stats.totalDisk, symbol: "internaldrive")
            }
            Text("macOS manages available RAM automatically. MacPulse never runs memory-purging commands or terminates apps without permission.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Button("Clean · Review Memory") { selected = .memory; store.refresh() }
                    .buttonStyle(.borderedProminent)
                Button("VPN") { selected = .vpn; store.refresh() }
                    .buttonStyle(.bordered)
                Button("Find Duplicates") { selected = .duplicates }
                Button("Analyze Storage") { selected = .storage }
            }
            Text("All processing is on your Mac. No account, subscriptions, telemetry or cloud scans.")
                .foregroundStyle(.secondary).font(.caption)
        }
    }

    private var memory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory review").font(.title2.bold())
            StatTile(title: "RAM in use · estimated", used: store.stats.usedMemory,
                     total: store.stats.totalMemory, symbol: "memorychip")
            Text("macOS automatically manages free and cached RAM. To release RAM safely, review user apps and request a normal quit only when you want to close them. Unsaved work may require confirmation.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Refresh Running Apps") { store.refresh() }
                Button("Review Old Logs (Disk Cleanup)") { selected = .cleanup; store.scanLogs() }
            }
            ForEach(store.memoryApps.prefix(40)) { app in
                HStack {
                    VStack(alignment: .leading) {
                        Text(app.name).font(.headline)
                        Text("PID \(app.pid) · Resident \(SystemSnapshot.bytes(app.residentBytes))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Quit…") { store.requestQuit(app) }
                }
                .padding(9)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @State private var minimumFileMB: Double = 50

    private var storage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Storage Analyzer · Read-only until confirmed").font(.title2.bold())
            Text("Choose a folder to examine. MacPulse never scans system locations automatically. It skips hidden files, symlinks, and app packages, with a 20,000-entry limit; results are estimates rather than total disk usage.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Choose Folder…") { store.chooseStorageFolder() }
                    .buttonStyle(.borderedProminent)
                if let result = store.storageResult {
                    Button("Rescan") { store.analyze(folder: result.folder) }
                        .disabled(store.busy)
                    Button("Open Folder in Finder") { NSWorkspace.shared.open(result.folder) }
                }
            }
            if store.busy { ProgressView("Scanning…") }
            if let report = store.storageResult {
                Text(report.folder.path).font(.caption).textSelection(.enabled)
                HStack {
                    Text("Measured files: \(SystemSnapshot.bytes(report.totalBytes))")
                        .font(.headline)
                    Spacer()
                    Text("\(report.files.count) regular files")
                        .foregroundStyle(.secondary)
                }
                if report.wasLimited {
                    Label("20,000-entry limit reached; this is a partial scan.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                ForEach(report.categoryTotals) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.category.rawValue)
                            Spacer()
                            Text("\(item.count) files · \(SystemSnapshot.bytes(item.size))")
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: report.totalBytes > 0 ?
                            Double(item.size) / Double(report.totalBytes) : 0)
                    }
                }
                Divider()
                HStack {
                    Text("Largest files").font(.title3.bold())
                    Spacer()
                    Text("Min size: \(Int(minimumFileMB)) MB").font(.caption)
                    Slider(value: $minimumFileMB, in: 0...1000, step: 25)
                        .frame(width: 150)
                }
                Text("Select individual files before moving any to Trash. The list shows at most 250 matching files; scan results never trigger automatic deletion.")
                    .font(.caption).foregroundStyle(.secondary)
                let large = report.biggest.filter { $0.size >= UInt64(minimumFileMB * 1_048_576) }
                if large.isEmpty {
                    Text("No matching files in this folder. Lower the minimum size to see smaller files.")
                        .foregroundStyle(.secondary)
                }
                ForEach(large.prefix(250)) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            store.toggleStorageFile(item)
                        } label: {
                            Image(systemName: store.selectedStoragePaths.contains(item.id) ?
                                  "checkmark.square.fill" : "square")
                        }
                        .buttonStyle(.borderless)
                        VStack(alignment: .leading) {
                            Text(item.url.lastPathComponent).lineLimit(1).help(item.url.path)
                            Text(item.url.path).font(.caption2).foregroundStyle(.secondary)
                                .lineLimit(1).textSelection(.enabled)
                        }
                        Spacer()
                        Text(SystemSnapshot.bytes(item.size))
                            .font(.callout.monospacedDigit())
                    }
                }
                let selectedCount = store.selectedStoragePaths.count
                HStack {
                    Text("\(selectedCount) selected · " +
                         SystemSnapshot.bytes(report.files.filter {
                             store.selectedStoragePaths.contains($0.id)
                         }.reduce(0) { $0 + $1.size }))
                        .font(.callout)
                    Spacer()
                    Button("Move Selected to Trash…") { store.trashSelectedStorage() }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedCount == 0 || store.busy)
                }
            }
        }
    }

    private var cleanup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reversible cleanup").font(.title2.bold())
            Text("Scans only your own log files older than 14 days under ~/Library/Logs. Nothing is deleted automatically; selected files move to Trash after confirmation.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Scan Old Logs") { store.scanLogs() }
                Button("Clean · Move to Trash") { store.trashOldLogs() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.cleanup.isEmpty || store.busy)
            }
            Text("\(store.cleanup.count) eligible files · \(SystemSnapshot.bytes(store.cleanup.reduce(0) { $0 + $1.size }))")
                .font(.headline)
            ForEach(store.cleanup.prefix(100)) { entry in
                HStack {
                    Image(systemName: "doc.text")
                    Text(entry.url.lastPathComponent).lineLimit(1)
                    Spacer()
                    Text(SystemSnapshot.bytes(entry.size))
                        .foregroundStyle(.secondary)
                }
                .help(entry.url.path)
            }
        }
    }

    private var duplicates: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find exact duplicates").font(.title2.bold())
            Text("Pick a folder to scan. SHA-256 comparisons find identical files regardless of name. The first 3,000 files up to 200 MB each are checked; nothing is removed.")
                .foregroundStyle(.secondary)
            Button("Choose Folder to Scan") { store.chooseDuplicatesFolder() }
                .disabled(store.busy)
            if store.busy { ProgressView() }
            ForEach(store.duplicates) { group in
                VStack(alignment: .leading) {
                    Text("\(group.urls.count) copies · \(SystemSnapshot.bytes(group.size)) each")
                        .font(.headline)
                    ForEach(group.urls, id: \.path) { url in
                        Text(url.path).font(.caption).textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var vpn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VPN connections").font(.title2.bold())
            Text("Use the free Cloudflare WARP tier by installing its official client, or control a VPN connection already configured in macOS. MacPulse itself does not operate a VPN server or tunnel.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Text("Cloudflare WARP · optional free provider").font(.headline)
                if VPNControl.warpCLI != nil {
                    Text(store.warpStatus ?? "Checking official WARP client status...")
                        .font(.caption).textSelection(.enabled)
                    Button(VPNControl.warpConnected(store.warpStatus ?? "") ? "Disconnect WARP" : "Connect WARP") {
                        store.toggleWarp()
                    }
                    .disabled(store.warpStatus == nil || store.busy)
                    Text("Connection and encryption depend on WARP mode, configuration, and Cloudflare client. Check its status before assuming traffic is protected.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("The official Cloudflare WARP CLI is not installed. Install its free macOS client and activate it first; MacPulse can then control it.")
                        .foregroundStyle(.secondary)
                    Link("Get Cloudflare WARP for macOS", destination:
                         URL(string: "https://developers.cloudflare.com/warp-client/get-started/macos/")!)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            Text("Existing macOS VPN profiles").font(.headline)
            if store.vpn.isEmpty {
                Label("No compatible system VPN configuration detected", systemImage: "network.slash")
                    .foregroundStyle(.orange)
            }
            ForEach(store.vpn) { service in
                HStack {
                    Image(systemName: service.connected ? "lock.shield.fill" : "lock.open")
                    VStack(alignment: .leading) {
                        Text(service.name).font(.headline)
                        Text(service.status).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(service.connected ? "Disconnect" : "Connect") { store.toggleVPN(service) }
                        .disabled(store.busy)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            Button("Open macOS Network Settings") { VPNControl.openSettings() }
        }
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional macOS tools").font(.title2.bold())
            Button("Open Applications (review installed apps)") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
            }
            Button("Open Login Items & Extensions") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Open macOS Security Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                    NSWorkspace.shared.open(url)
                }
            }
            Link("Check for MacPulse Updates", destination: URL(string: "https://github.com/sujanmj/macapp/releases")!)
            Divider()
            Text("Not yet provided: antivirus signatures and real-time malware protection, adware detection, browser ad blockers, password breach monitoring, automatic app uninstallation, and an independent VPN network.")
                .foregroundStyle(.secondary)
            Text("This version does not claim to scan for viruses or provide an anonymous network connection.")
                .foregroundStyle(.orange).font(.callout)
        }
    }
}

@main
struct MacPulseApp: App {
    @StateObject private var store = PulseStore()
    var body: some Scene {
        WindowGroup("MacPulse") {
            MainView(store: store)
        }
        .defaultSize(width: 900, height: 630)

        MenuBarExtra("MacPulse", systemImage: "waveform.path.ecg") {
            Text("Memory: \(SystemSnapshot.bytes(store.stats.usedMemory)) / \(SystemSnapshot.bytes(store.stats.totalMemory))")
            Text("Disk free: \(SystemSnapshot.bytes(store.stats.freeDisk))")
            Divider()
            Button("Clean · Review Memory") { store.route(URL(string: "macpulse://clean")!) }
            Button("VPN Controls") { store.route(URL(string: "macpulse://vpn")!) }
            Button("Storage Analyzer") { store.route(URL(string: "macpulse://storage")!) }
            Button("Refresh") { store.refresh() }
            Divider()
            Link("About / Releases", destination: URL(string: "https://github.com/sujanmj/macapp/releases")!)
        }
    }
}
