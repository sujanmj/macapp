import Foundation

struct SubtitleCue: Equatable {
    let text: String
    let start: TimeInterval
    let duration: TimeInterval
}

enum SubtitleFormatter {
    static func srt(_ cues: [SubtitleCue]) -> String {
        cues.compactMap { cue -> (String, TimeInterval, TimeInterval)? in
            let text = cue.text
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, cue.start.isFinite, cue.duration.isFinite else { return nil }
            let start = max(0, cue.start)
            let end = max(start + 0.05, start + max(0, cue.duration))
            return (text, start, end)
        }
        .enumerated()
        .map { index, cue in
            "\(index + 1)\n\(timestamp(cue.1)) --> \(timestamp(cue.2))\n\(cue.0)"
        }
        .joined(separator: "\n\n")
    }

    private static func timestamp(_ time: TimeInterval) -> String {
        let milliseconds = Int64((max(0, time) * 1000).rounded(.down))
        let hours = milliseconds / 3_600_000
        let minutes = (milliseconds / 60_000) % 60
        let seconds = (milliseconds / 1_000) % 60
        let remainder = milliseconds % 1_000
        return String(format: "%02lld:%02lld:%02lld,%03lld", hours, minutes, seconds, remainder)
    }
}
