import SwiftUI
import AppKit

struct NotchGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.appearance = NSAppearance(named: .aqua)
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct GlassCard: ViewModifier {
    var tint: Color
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.09), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.22), lineWidth: 0.7))
        }
    }
}

struct NotchControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(LinearGradient(colors: [.cyan.opacity(configuration.isPressed ? 0.45 : 0.25), .indigo.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
