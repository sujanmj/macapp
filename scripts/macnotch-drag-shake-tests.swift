import Foundation

@main
struct MacNotchDragShakeTests {
    static func main() {
        var detector = DragShakeDetector()
        let shake: [(CGFloat, TimeInterval)] = [(0, 0), (24, 0.08), (0, 0.16), (24, 0.24), (0, 0.32)]
        let reveals = shake.enumerated().filter { detector.update(point: CGPoint(x: $0.element.0, y: 100), time: $0.element.1) }
        precondition(reveals.count == 1, "A fast, deliberate two-reversal shake should reveal the shelf exactly once.")
        precondition(!detector.update(point: CGPoint(x: 24, y: 100), time: 0.4), "A single drag direction must not reveal the shelf.")
        precondition(!detector.update(point: CGPoint(x: 0, y: 100), time: 0.5), "The reveal cooldown must prevent duplicate openings.")

        detector.reset()
        let slow: [(CGFloat, TimeInterval)] = [(0, 1.0), (30, 1.4), (0, 1.8), (30, 2.2), (0, 2.6)]
        let slowReveal = slow.contains { detector.update(point: CGPoint(x: $0.0, y: 100), time: $0.1) }
        precondition(!slowReveal, "Slow movement must not be mistaken for a shake.")
        print("MacNotch drag-shake checks passed")
    }
}
