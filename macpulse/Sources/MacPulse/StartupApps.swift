import SwiftUI
import AppKit
import ServiceManagement
import Carbon

struct StartupItem: Identifiable {
    let name: String
    let path: String
    let legacy: Bool
    var id: String { "\(legacy):\(path):\(name)" }
}

@MainActor
final class StartupManager: ObservableObject {
    @Published var items: [StartupItem] = []
    @Published var status = "Refresh to inspect login items. macOS may request Automation access to System Events."

    func refresh() {
        var error: NSDictionary?
        let script = NSAppleScript(source: "tell application \"System Events\" to get {name, path} of every login item")
        let result = script?.executeAndReturnError(&error)
        var found: [StartupItem] = []
        if error == nil, let result, result.numberOfItems == 2,
           let names = result.atIndex(1), let paths = result.atIndex(2), names.numberOfItems > 0 {
            for i in 1...names.numberOfItems {
                if let name = names.atIndex(i)?.stringValue, let path = paths.atIndex(i)?.stringValue {
                    found.append(StartupItem(name: name, path: path, legacy: true))
                }
            }
        }
        // Read-only inventory of third-party launch definitions; presence does
        // not prove a service is enabled. Modern BTM items are shown by Settings.
        let folders = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
                       URL(fileURLWithPath: "/Library/LaunchAgents"), URL(fileURLWithPath: "/Library/LaunchDaemons")]
        for folder in folders {
            for url in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: url),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let label = plist["Label"] as? String, !label.hasPrefix("com.apple.") else { continue }
                found.append(StartupItem(name: label, path: url.path, legacy: false))
            }
        }
        items = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        status = error == nil ? "Legacy login items and third-party launch definitions. Launch definitions may be inactive. For the authoritative modern background-item list, open Login Items Settings." : "Login-item access unavailable or denied. Launch definitions shown below may be inactive. Use Login Items Settings to inspect and disable startup apps."
    }

    func disable(_ item: StartupItem) {
        guard item.legacy else { SMAppService.openSystemSettingsLoginItems(); return }
        let alert = NSAlert()
        alert.messageText = "Remove \(item.name) from login items?"
        alert.informativeText = "This removes only the legacy launch-at-login entry. It does not quit or uninstall the app. Other startup services must be managed in System Settings."
        alert.addButton(withTitle: "Remove Login Item")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        // Pass data as Apple event strings, never interpolate names into code.
        let script = NSAppleScript(source: "on removeItem(itemName, itemPath)\n tell application \"System Events\"\n set matches to every login item whose name is itemName and path is itemPath\n if (count matches) is not 1 then error \"Login item changed; refresh and retry.\"\n delete item 1 of matches\n end tell\nend removeItem")!
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kASAppleScriptSuite), eventID: AEEventID(kASSubroutineEvent), targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: "removeitem"), forKeyword: AEKeyword(keyASSubroutineName))
        let args = NSAppleEventDescriptor.list()
        args.insert(NSAppleEventDescriptor(string: item.name), at: 1)
        args.insert(NSAppleEventDescriptor(string: item.path), at: 2)
        event.setParam(args, forKeyword: AEKeyword(keyDirectObject))
        var error: NSDictionary?
        script.executeAppleEvent(event, error: &error)
        refresh()
        if error != nil { status = "Could not remove login item. It may have changed or Automation access was denied. Use Login Items Settings." }
    }
}

struct StartupAppsView: View {
    @StateObject private var manager = StartupManager()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Startup & background apps").font(.title2.bold())
            Text(manager.status).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Refresh Startup Items") { manager.refresh() }
                Button("Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
            }
            ForEach(manager.items) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name).lineLimit(1)
                        Text(item.legacy ? "Legacy login item" : "Background launch definition · status unknown").font(.caption)
                        Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button(item.legacy ? "Disable…" : "Manage in Settings") { manager.disable(item) }
                }
            }
            Divider()
            Text("High-RAM apps: open Memory Cleaner to review resident memory and request a confirmed normal quit. Apps can refuse or ask to save work.").font(.caption)
            Link("Review RAM usage", destination: URL(string: "macpulse://clean")!)
        }
    }
}
