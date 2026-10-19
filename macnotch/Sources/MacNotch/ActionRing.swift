import SwiftUI

struct CustomActionRingShortcut: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var target: String
    var isApplication: Bool

    init(title: String, target: String, isApplication: Bool) {
        id = UUID()
        self.title = title
        self.target = target
        self.isApplication = isApplication
    }
}

struct ActionRingOption: Identifiable {
    let id: String
    let title: String
    let symbol: String

    static let all: [ActionRingOption] = [
        .init(id: "tray", title: "File Tray", symbol: "tray.full.fill"),
        .init(id: "music", title: "Music", symbol: "music.note"),
        .init(id: "widgets", title: "Widgets", symbol: "chart.bar.fill"),
        .init(id: "record", title: "Record", symbol: "record.circle.fill"),
        .init(id: "focus", title: "Focus", symbol: "timer"),
        .init(id: "gemini", title: "Gemini", symbol: "sparkles"),
        .init(id: "notes", title: "Notes", symbol: "note.text"),
        .init(id: "settings", title: "Settings", symbol: "gearshape.fill")
    ]
}

struct ActionRingAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color
    let perform: () -> Void
}

struct ActionRingView: View {
    @ObservedObject var store: NotchStore
    let actions: [ActionRingAction]
    let onDismiss: () -> Void

    private var visibleActions: [ActionRingAction] {
        let ranks = Dictionary(uniqueKeysWithValues: store.actionRingActionIDs.enumerated().map { ($1, $0) })
        let builtIn = actions.filter { ranks[$0.id] != nil }.sorted {
            ranks[$0.id, default: Int.max] < ranks[$1.id, default: Int.max]
        }
        let custom = store.customRingShortcuts.map { shortcut in
            ActionRingAction(
                id: "custom-\(shortcut.id.uuidString)",
                title: shortcut.title,
                symbol: shortcut.isApplication ? "app.fill" : "globe",
                tint: shortcut.isApplication ? .mint : .cyan
            ) {
                let url = shortcut.isApplication
                    ? URL(fileURLWithPath: shortcut.target)
                    : URL(string: shortcut.target)
                if let url { NSWorkspace.shared.open(url) }
            }
        }
        return builtIn + custom
    }

    var body: some View {
        GeometryReader { geometry in ringContent(size: geometry.size) }
        .frame(width: 360, height: 360)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private func ringContent(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.34
        return ZStack {
            ringBackground(center: center, radius: radius)
            actionButtons(center: center, radius: radius)
            centerButton(center: center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ringBackground(center: CGPoint, radius: CGFloat) -> some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(.black.opacity(0.88)))
            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
            .frame(width: radius * 2.7, height: radius * 2.7)
            .position(center)
    }

    private func actionButtons(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(visibleActions.indices, id: \.self) { index in
            actionButton(at: index, center: center, radius: radius)
        }
    }

    private func actionButton(at index: Int, center: CGPoint, radius: CGFloat) -> some View {
        let action = visibleActions[index]
        let angle = (2 * Double.pi * Double(index) / Double(max(1, visibleActions.count))) - Double.pi / 2
        let x = center.x + CGFloat(cos(angle)) * radius
        let y = center.y + CGFloat(sin(angle)) * radius
        let compact = visibleActions.count > 10
        return Button {
            onDismiss()
            action.perform()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: action.symbol)
                    .font(.system(size: compact ? 15 : 19, weight: .semibold))
                    .foregroundStyle(action.tint)
                Text(action.title)
                    .font(.system(size: compact ? 7 : 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: compact ? 46 : 66, height: compact ? 48 : 62)
            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: compact ? 13 : 17))
            .overlay(RoundedRectangle(cornerRadius: compact ? 13 : 17).stroke(action.tint.opacity(0.23), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: compact ? 13 : 17))
        }
        .buttonStyle(.plain)
        .help(action.title)
        .position(x: x, y: y)
    }

    private func centerButton(center: CGPoint) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.cyan)
            Text("MacNotch").font(.system(size: 10, weight: .semibold))
            Button("Close", action: onDismiss)
                .font(.system(size: 9))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .frame(width: 86, height: 86)
        .background(.black.opacity(0.74), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        .position(center)
    }
}
