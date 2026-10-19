import Foundation

struct TeleprompterPlayback {
    private(set) var distance: Double = 0
    private(set) var startedAt: Date?
    private(set) var pointsPerSecond: Double

    init(pointsPerSecond: Double = 45) {
        self.pointsPerSecond = Self.sanitizedSpeed(pointsPerSecond)
    }

    var isRunning: Bool { startedAt != nil }

    mutating func start(at date: Date) {
        guard startedAt == nil else { return }
        startedAt = date
    }

    mutating func pause(at date: Date) {
        guard let startedAt else { return }
        distance += max(0, date.timeIntervalSince(startedAt)) * pointsPerSecond
        self.startedAt = nil
    }

    mutating func setSpeed(_ speed: Double, at date: Date) {
        if let startedAt {
            distance += max(0, date.timeIntervalSince(startedAt)) * pointsPerSecond
            self.startedAt = date
        }
        pointsPerSecond = Self.sanitizedSpeed(speed)
    }

    mutating func reset() {
        distance = 0
        startedAt = nil
    }

    func offset(at date: Date) -> Double {
        let liveDistance = distance + (startedAt.map { max(0, date.timeIntervalSince($0)) * pointsPerSecond } ?? 0)
        return max(0, liveDistance)
    }

    private static func sanitizedSpeed(_ speed: Double) -> Double {
        speed.isFinite ? min(120, max(10, speed)) : 45
    }
}
