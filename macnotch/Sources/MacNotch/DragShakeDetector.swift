import Foundation

struct DragShakeDetector {
    private struct Sample {
        let point: CGPoint
        let time: TimeInterval
    }

    private var samples: [Sample] = []
    private var lastReveal = -Double.greatestFiniteMagnitude

    private let observationWindow: TimeInterval = 0.8
    private let minimumStep: CGFloat = 9
    private let minimumPath: CGFloat = 72
    private let revealCooldown: TimeInterval = 1.3

    mutating func update(point: CGPoint, time: TimeInterval) -> Bool {
        guard point.x.isFinite, point.y.isFinite, time.isFinite else { return false }
        let next = Sample(point: point, time: time)
        if let last = samples.last, time < last.time || time - last.time > observationWindow {
            samples = [next]
            return false
        }
        guard let last = samples.last else {
            samples = [next]
            return false
        }
        let step = hypot(point.x - last.point.x, point.y - last.point.y)
        guard step >= minimumStep else { return false }
        samples.append(next)
        samples.removeAll { time - $0.time > observationWindow }

        let pathLength = zip(samples, samples.dropFirst()).reduce(CGFloat.zero) { total, pair in
            total + hypot(pair.1.point.x - pair.0.point.x, pair.1.point.y - pair.0.point.y)
        }
        let vectors = zip(samples, samples.dropFirst()).map {
            CGPoint(x: $0.1.point.x - $0.0.point.x, y: $0.1.point.y - $0.0.point.y)
        }
        let reversals = zip(vectors, vectors.dropFirst()).reduce(0) { count, pair in
            let dot = pair.0.x * pair.1.x + pair.0.y * pair.1.y
            let magnitude = max(1, hypot(pair.0.x, pair.0.y) * hypot(pair.1.x, pair.1.y))
            return count + (dot / magnitude < -0.25 ? 1 : 0)
        }
        guard pathLength >= minimumPath, reversals >= 2, time - lastReveal >= revealCooldown else { return false }
        lastReveal = time
        samples = [next]
        return true
    }

    mutating func reset() { samples.removeAll(keepingCapacity: true) }
}
