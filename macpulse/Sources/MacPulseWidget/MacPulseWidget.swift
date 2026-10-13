import SwiftUI
import WidgetKit

struct PulseEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSnapshot
}

struct PulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, snapshot: .read())
    }
    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(PulseEntry(date: .now, snapshot: .read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        let now = Date()
        let entry = PulseEntry(date: now, snapshot: .read())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300))))
    }
}

struct PulseWidgetView: View {
    let entry: PulseEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundStyle(.cyan)
                Text("MacPulse")
                    .font(.headline)
                Spacer()
                Text("\(Int(entry.snapshot.memoryRatio * 100))%")
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            ProgressView(value: entry.snapshot.memoryRatio)
                .tint(.cyan)
            Text("\(SystemSnapshot.bytes(entry.snapshot.usedMemory)) of \(SystemSnapshot.bytes(entry.snapshot.totalMemory)) RAM")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.75)
            HStack(spacing: 10) {
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
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red:0.05,green:0.15,blue:0.24),
                                    Color(red:0.11,green:0.25,blue:0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .foregroundStyle(.white)
    }
}

struct MacPulseDesktopWidget: Widget {
    let kind = "MacPulseDesktopWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseProvider()) { entry in
            PulseWidgetView(entry: entry)
        }
        .configurationDisplayName("MacPulse · Memory & VPN")
        .description("See estimated RAM in use. Clean opens a safe review; VPN opens connection controls.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct MacPulseWidgetExtension: WidgetBundle {
    var body: some Widget {
        MacPulseDesktopWidget()
    }
}
