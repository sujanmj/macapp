import SwiftUI
import AppKit

struct NotchGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.appearance = NSAppearance(named: .darkAqua)
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
                .fill(LinearGradient(colors: [.black.opacity(0.34), tint.opacity(0.20), tint.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.13), lineWidth: 0.7))
        }
    }
}

struct NotchControlStyle: ButtonStyle {
    var tint: Color = Color(red: 0.31, green: 0.40, blue: 1.0)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(LinearGradient(colors: [tint.opacity(configuration.isPressed ? 0.38 : 0.24), tint.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.6))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
