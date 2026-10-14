import SwiftUI
import AppKit
import Quartz
import Carbon

struct ShelfItem: Identifiable {
    let url: URL
    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
}

@MainActor
final class ShelfStore: NSObject, ObservableObject, @preconcurrency QLPreviewPanelDataSource {
    @Published var items: [ShelfItem] = []
    @Published var selected = Set<String>()
    @Published var message = "Drop files from different folders here, then drag the batch out or copy and paste in Finder."
    private let persist: Bool
    private var importGeneration = UUID()
    private var previewURL: URL?
    private var receivers: [NSFilePromiseReceiver] = []
    private let promisesQueue = OperationQueue()
    init(persist: Bool = true) {
        self.persist = persist
        super.init()
        promisesQueue.maxConcurrentOperationCount = 1
        guard persist else { return }
        for data in UserDefaults.standard.array(forKey: "shelfBookmarks") as? [Data] ?? [] {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) {
                items.append(ShelfItem(url: url))
            }
        }
        items = Array(items.prefix(300))
    }
    func save() {
        guard persist else { return }
        let bookmarks = items.compactMap { try? $0.url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) }
        UserDefaults.standard.set(bookmarks, forKey: "shelfBookmarks")
    }
    func add(_ urls: [URL]) {
        var ids = Set(items.map(\.id))
        var skipped = 0
        for url in urls where url.isFileURL {
            let item = ShelfItem(url: url.standardizedFileURL)
            guard !ids.contains(item.id) else { continue }
            if items.count < 300 { ids.insert(item.id); items.append(item) }
            else { skipped += 1 }
        }
        save()
        message = "\(items.count) file references held. Original files stay where they are." + (skipped > 0 ? " Shelf limit reached; \(skipped) files were not added." : "")
    }
    var batch: [ShelfItem] { items.filter { (selected.isEmpty || selected.contains($0.id)) && $0.exists } }
    func choose() {
        let picker = NSOpenPanel()
        picker.allowsMultipleSelection = true; picker.canChooseDirectories = true
        if picker.runModal() == .OK { add(picker.urls) }
    }
    func pasteFiles() {
        let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if urls.isEmpty { message = "The clipboard contains no file references." } else { add(urls) }
    }
    func copyBatch() {
        guard !batch.isEmpty else { message = "Select existing files first."; return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(batch.map { $0.url as NSURL })
        message = "Copied \(batch.count) file references. Paste into Finder or a compatible app."
    }
    func removeSelection() {
        guard !selected.isEmpty else { return }
        items.removeAll { selected.contains($0.id) }; selected.removeAll(); save()
        message = "Removed references from shelf. Original files were untouched."
    }
    func clear() { importGeneration = UUID(); items.removeAll(); selected.removeAll(); save(); message = "Shelf cleared. Original files were untouched." }
    func receive(_ board: NSPasteboard) -> Bool {
        let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !urls.isEmpty { add(urls); return true }
        guard let promises = board.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver], !promises.isEmpty else {
            message = "This drop does not offer files. Export photos/documents as files first."; return false
        }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacShelf/Imports/" + UUID().uuidString)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch { message = error.localizedDescription; return false }
        let session = importGeneration
        receivers.append(contentsOf: promises)
        for receiver in promises {
            receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: promisesQueue) { [weak self] url, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.receivers.removeAll { $0 === receiver }
                    guard self.importGeneration == session else { return }
                    if let error { self.message = "File export failed: " + error.localizedDescription }
                    else { self.add([url]) }
                }
            }
        }
        message = "Receiving exported files…"; return true
    }
    func preview() {
        previewURL = batch.first?.url
        guard previewURL != nil, let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self; panel.reloadData(); panel.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURL == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { previewURL as NSURL? }
}

/// Uses one NSDraggingItem per file, so Finder/browser targets receive a batch.
final class ShelfDragView: NSView, NSDraggingSource {
    var store: ShelfStore?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12).fill()
        let label = "↓ Drop files here   ·   Drag this bar to carry the batch →"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.labelColor]
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: max(10, (bounds.width - size.width) / 2), y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { store?.receive(sender.draggingPasteboard) ?? false }
    override func mouseDragged(with event: NSEvent) {
        guard let store, !store.batch.isEmpty else { return }
        let origin = convert(event.locationInWindow, from: nil)
        let draggingItems = store.batch.map { item -> NSDraggingItem in
            let dragging = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: item.url.path)
            dragging.setDraggingFrame(NSRect(x: origin.x, y: origin.y, width: 40, height: 40), contents: icon)
            return dragging
        }
        beginDraggingSession(with: draggingItems, event: event, source: self).animatesToStartingPositionsOnCancelOrFail = true
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}

struct BatchDragArea: NSViewRepresentable {
    let store: ShelfStore
    func makeNSView(context: Context) -> ShelfDragView { let view = ShelfDragView(); view.store = store; return view }
    func updateNSView(_ view: ShelfDragView, context: Context) { view.store = store; view.needsDisplay = true }
}

struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    @AppStorage("shakeShelf") private var shake = true
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MacShelf", systemImage: "tray.2.fill").font(.title2.bold())
                Spacer(); Text("\(store.items.count) files").foregroundStyle(.secondary)
            }
            BatchDragArea(store: store).frame(height: 58)
            List(selection: $store.selected) {
                ForEach(store.items) { item in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().frame(width: 28, height: 28)
                        VStack(alignment: .leading) {
                            Text(item.name).lineLimit(1)
                            Text(item.exists ? item.url.deletingLastPathComponent().path : "Missing · moved or deleted outside shelf")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }.tag(item.id)
                }
            }.frame(minHeight: 170)
            HStack {
                Button("Add…") { store.choose() }
                Button("Paste Files") { store.pasteFiles() }.keyboardShortcut("v")
                Button("Select All") { store.selected = Set(store.items.map(\.id)) }.keyboardShortcut("a")
                Button("Copy Batch") { store.copyBatch() }.keyboardShortcut("c")
                Button("Preview") { store.preview() }
            }
            HStack {
                Button("Remove Selected") { store.removeSelection() }.disabled(store.selected.isEmpty)
                Button("Clear Shelf") { store.clear() }
                Spacer(); Toggle("Shake to show", isOn: $shake).toggleStyle(.checkbox)
            }
            Text(store.message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("⌃⌥S opens shelf · ⌘-click selects multiple · outgoing drags copy files").font(.caption2)
        }.padding(16).frame(minWidth: 560, minHeight: 360)
    }
}

@MainActor
final class ShelfDelegate: NSObject, NSApplicationDelegate {
    let store = ShelfStore()
    let shortcut = GlobalShortcut()
    var window: FloatingWindow?
    var monitor: Any?
    var movements: [(Double, TimeInterval)] = []
    var lastX: Double?
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = FloatingWindow(title: "MacShelf", size: NSSize(width: 620, height: 430), content: ShelfView(store: store))
        shortcut.action = { [weak self] in self?.window?.show() }
        if !shortcut.register(key: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey)) { store.message = "Shortcut unavailable; use the menu bar to open the shelf." }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            Task { @MainActor in self?.observeShake(event) }
        }
        window?.show()
    }
    func observeShake(_ event: NSEvent) {
        guard UserDefaults.standard.object(forKey: "shakeShelf") as? Bool ?? true else { return }
        let x = NSEvent.mouseLocation.x; defer { lastX = x }
        guard let old = lastX, abs(x - old) > 8 else { return }
        movements.append((x - old, event.timestamp))
        movements.removeAll { event.timestamp - $0.1 > 0.7 }
        let changes = zip(movements, movements.dropFirst()).filter { $0.0.0 * $0.1.0 < 0 }.count
        if changes >= 3 {
            window?.panel.orderFrontRegardless()
            movements.removeAll()
        }
    }
    func application(_ sender: NSApplication, open urls: [URL]) { store.add(urls); window?.show() }
    func applicationWillTerminate(_ notification: Notification) { if let monitor { NSEvent.removeMonitor(monitor) } }
}

@main
struct MacShelfApp: App {
    @NSApplicationDelegateAdaptor(ShelfDelegate.self) var delegate
    var body: some Scene {
        MenuBarExtra("MacShelf", systemImage: "tray.2.fill") {
            Button("Show File Shelf") { delegate.window?.show() }
            Button("Add Files…") { delegate.window?.show(); delegate.store.choose() }
            SettingsLink()
            Divider(); Button("Quit MacShelf") { NSApp.terminate(nil) }
        }
        Settings { VStack(alignment: .leading, spacing: 12) { LoginToggle(); Text("Shelf references persist locally. Exported file promises remain in Application Support/MacShelf/Imports until you remove those imported files in Finder.").font(.caption) }.padding(20).frame(width: 420) }
    }
}
