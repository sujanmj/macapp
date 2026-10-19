import SwiftUI

struct ActionRingAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color
    let perform: () -> Void
}

struct ActionRingView: View {
    let actions: [ActionRingAction]
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) * 0.34
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(.black.opacity(0.88)))
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                    .frame(width: radius * 2.7, height: radius * 2.7)
                    .position(center)

                ForEach(actions.indices, id: \.self) { index in
                    let angle = (2 * Double.pi * Double(index) / Double(max(1, actions.count))) - Double.pi / 2
                    let action = actions[index]
                    Button {
                        onDismiss()
                        action.perform()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: action.symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(action.tint)
                            Text(action.title).font(.system(size: 9, weight: .medium)).lineLimit(1)
                        }
                        .frame(width: 66, height: 62)
                        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(action.tint.opacity(0.23), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)
                    .help(action.title)
                    .position(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                }

                VStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 21, weight: .semibold)).foregroundStyle(.cyan)
                    Text("MacNotch").font(.system(size: 10, weight: .semibold))
                    Button("Close", action: onDismiss).font(.system(size: 9)).buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .frame(width: 86, height: 86)
                .background(.black.opacity(0.74), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                .position(center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 360, height: 360)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}
