import SwiftUI
import WidgetKit
import AppIntents

/// The widget can be edited from the macOS Widget Gallery.
enum PulseWidgetFocus: String, AppEnum {
    case memory
    case storage

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "System Metric"
    static var caseDisplayRepresentations: [PulseWidgetFocus: DisplayRepresentation] = [
        .memory: "Memory",
        .storage: "Storage"
    ]
}

struct PulseWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Customize MacPulse"
    static var description = IntentDescription("Choose the main metric and whether to show quick-action links.")

    @Parameter(title: "Primary metric", default: .memory)
    var primaryMetric: PulseWidgetFocus

    @Parameter(title: "Show quick actions", default: true)
    var showActions: Bool

    init() {}
}

struct PulseEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSnapshot
    let configuration: PulseWidgetConfiguration
}

struct PulseProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, snapshot: .read(), configuration: PulseWidgetConfiguration())
    }

    func snapshot(for configuration: PulseWidgetConfiguration, in context: Context) async -> PulseEntry {
        PulseEntry(date: .now, snapshot: .read(), configuration: configuration)
    }

    func timeline(for configuration: PulseWidgetConfiguration, in context: Context) async -> Timeline<PulseEntry> {
        let now = Date()
        let entry = PulseEntry(date: now, snapshot: .read(), configuration: configuration)
        // Scheduling is advisory. WidgetKit decides when to refresh for battery life.
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))
    }
}

private struct MetricValues {
    let title: String
    let symbol: String
    let used: UInt64
    let total: UInt64
    let destination: URL

    var ratio: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    init(_ focus: PulseWidgetFocus, snapshot: SystemSnapshot) {
        switch focus {
        case .memory:
            title = "Memory in use"
            symbol = "memorychip"
            used = snapshot.usedMemory
            total = snapshot.totalMemory
            destination = URL(string: "macpulse://clean")!
        case .storage:
            title = "Disk space used"
            symbol = "internaldrive"
            used = snapshot.totalDisk - snapshot.freeDisk
            total = snapshot.totalDisk
            destination = URL(string: "macpulse://storage")!
        }
    }
}

struct PulseWidgetView: View {
    let entry: PulseEntry
    @Environment(\.widgetFamily) private var family

    private var focused: MetricValues {
        MetricValues(entry.configuration.primaryMetric, snapshot: entry.snapshot)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: smallWidget
            case .systemLarge: largeWidget
            default: mediumWidget
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.16, blue: 0.24),
                         Color(red: 0.09, green: 0.30, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .foregroundStyle(.white)
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("MacPulse", systemImage: focused.symbol)
                .font(.headline).lineLimit(1)
            Spacer(minLength: 4)
            Text("\(Int(focused.ratio * 100))%")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .monospacedDigit()
            ProgressView(value: focused.ratio)
                .tint(.cyan)
            Text(focused.title)
                .font(.caption2).lineLimit(1)
        }
        .padding(14)
        // Small widget has one tap target. The configured metric determines it.
        .widgetURL(focused.destination)
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("MacPulse", systemImage: focused.symbol).font(.headline)
                Spacer()
                Text("\(Int(focused.ratio * 100))%")
                    .font(.title3.bold()).monospacedDigit()
            }
            ProgressView(value: focused.ratio).tint(.cyan)
            HStack(alignment: .firstTextBaseline) {
                Text(focused.title).font(.caption)
                Spacer()
                Text("\(SystemSnapshot.bytes(focused.used)) of \(SystemSnapshot.bytes(focused.total))")
                    .font(.caption2).monospacedDigit().lineLimit(1)
            }
            if entry.configuration.showActions {
                quickActions
            } else {
                Text("Customize this widget with Edit Widget")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 17) {
            Label("MacPulse · System Overview", systemImage: "waveform.path.ecg")
                .font(.headline)
            metricRow(MetricValues(.memory, snapshot: entry.snapshot))
            metricRow(MetricValues(.storage, snapshot: entry.snapshot))
            Divider()
            Text("Widget data refreshes periodically, not continuously.")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if entry.configuration.showActions {
                quickActions
            }
        }
        .padding(18)
    }

    private func metricRow(_ metric: MetricValues) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(metric.title, systemImage: metric.symbol)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(metric.ratio * 100))%")
                    .font(.title3.bold()).monospacedDigit()
            }
            ProgressView(value: metric.ratio).tint(.cyan)
            Text("\(SystemSnapshot.bytes(metric.used)) of \(SystemSnapshot.bytes(metric.total))")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 9) {
            Link(destination: URL(string: "macpulse://clean")!) {
                Label("Clean", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Link(destination: URL(string: "macpulse://vpn")!) {
                Label("VPN", systemImage: "network.badge.shield.half.filled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

struct MacPulseDesktopWidget: Widget {
    let kind = "MacPulseDesktopWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PulseWidgetConfiguration.self,
            provider: PulseProvider()
        ) { entry in
            PulseWidgetView(entry: entry)
        }
        .configurationDisplayName("MacPulse · Memory & System")
        .description("Choose memory or storage; open safe Clean and VPN controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct MacPulseWidgetExtension: WidgetBundle {
    var body: some Widget {
        MacPulseDesktopWidget()
    }
}
