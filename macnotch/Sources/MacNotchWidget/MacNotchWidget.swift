import SwiftUI
import WidgetKit

struct NotchWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: NotchWidgetSnapshot?
}

struct NotchWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotchWidgetEntry {
        NotchWidgetEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NotchWidgetEntry) -> Void) {
        completion(NotchWidgetEntry(date: .now, snapshot: NotchWidgetSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotchWidgetEntry>) -> Void) {
        let now = Date()
        let entry = NotchWidgetEntry(date: now, snapshot: NotchWidgetSnapshot.read())
        // This is a snapshot. WidgetKit may delay refreshes to manage battery and performance.
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300))))
    }
}

struct MacNotchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NotchWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemLarge: large
            default: medium
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.035, green: 0.045, blue: 0.075),
                                    Color(red: 0.10, green: 0.12, blue: 0.19)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("MacNotch", systemImage: "waveform.path.ecg").font(.headline)
            Spacer(minLength: 0)
            if let snapshot = entry.snapshot {
                Text("\(memoryPercent(snapshot))%")
                    .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                Text("RAM used").font(.caption)
                ProgressView(value: Double(snapshot.memoryUsed), total: Double(max(1, snapshot.memoryTotal)))
                    .tint(Color.cyan)
                Text("Disk free · \(bytes(snapshot.diskFree))").font(.caption2).lineLimit(1)
                ageLabel(snapshot)
            } else {
                Text("Open MacNotch to start a local system snapshot.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let snapshot = entry.snapshot {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        metric("RAM", value: "\(memoryPercent(snapshot))% · \(bytes(snapshot.memoryUsed))")
                        metric("CPU", value: String(format: "%.0f%%", snapshot.cpu))
                        metric("Top app", value: topApp(snapshot))
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 7) {
                        metric("Network", value: "↓ \(rate(snapshot.download))  ↑ \(rate(snapshot.upload))")
                        metric("Disk free", value: bytes(snapshot.diskFree))
                        Text("Local sample · \(snapshot.date, style: .time)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ageLabel(snapshot)
            } else {
                Spacer(minLength: 0)
                Text("Open MacNotch to create the first local snapshot. Keep the app open for updated data.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let snapshot = entry.snapshot {
                Text("\(memoryPercent(snapshot))% RAM in use")
                    .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                ProgressView(value: Double(snapshot.memoryUsed), total: Double(max(1, snapshot.memoryTotal))).tint(.cyan)
                HStack(spacing: 24) {
                    metric("Memory", value: "\(bytes(snapshot.memoryUsed)) / \(bytes(snapshot.memoryTotal))")
                    metric("CPU", value: String(format: "%.0f%%", snapshot.cpu))
                }
                HStack(spacing: 24) {
                    metric("Download", value: rate(snapshot.download))
                    metric("Upload", value: rate(snapshot.upload))
                }
                metric("Disk remaining", value: bytes(snapshot.diskFree))
                metric("Top RAM app", value: topApp(snapshot))
                Spacer(minLength: 0)
                ageLabel(snapshot)
            } else {
                Text("Open MacNotch to create the first local snapshot.").font(.caption)
            }
        }
        .padding(18)
    }

    private var header: some View {
        HStack {
            Label("MacNotch", systemImage: "waveform.path.ecg").font(.headline)
            Spacer()
            Text("SYSTEM").font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(1.1).foregroundStyle(.cyan)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.7)
                .foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
        }
    }

    private func ageLabel(_ snapshot: NotchWidgetSnapshot) -> some View {
        Text(Date().timeIntervalSince(snapshot.date) > 120
             ? "Stale snapshot · open MacNotch to refresh"
             : "Snapshot only · refresh timing is controlled by macOS")
            .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
    }

    private func topApp(_ snapshot: NotchWidgetSnapshot) -> String {
        guard let name = snapshot.topApp else { return "Unavailable" }
        guard let bytes = snapshot.topBytes else { return name }
        return "\(name) · \(bytesString(bytes))"
    }

    private func memoryPercent(_ snapshot: NotchWidgetSnapshot) -> Int {
        guard snapshot.memoryTotal > 0 else { return 0 }
        return Int((Double(snapshot.memoryUsed) / Double(snapshot.memoryTotal) * 100).rounded())
    }

    private func bytes(_ value: UInt64) -> String { bytesString(value) }
    private func bytesString(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory)
    }
    private func rate(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .file) + "/s"
    }
}

struct MacNotchDesktopWidget: Widget {
    let kind = "MacNotchDesktopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotchWidgetProvider()) { entry in
            MacNotchWidgetView(entry: entry)
        }
        .configurationDisplayName("MacNotch · System Snapshot")
        .description("RAM, CPU, network rates, free disk, and top RAM app. Timestamped snapshots; keep MacNotch open for updates.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct MacNotchWidgetExtension: WidgetBundle {
    var body: some Widget { MacNotchDesktopWidget() }
}
