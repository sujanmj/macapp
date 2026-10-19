import Foundation

@main
struct SubtitleFormatterChecks {
    static func main() {
        let result = SubtitleFormatter.srt([
            SubtitleCue(text: " Hello\nthere ", start: 0.125, duration: 1.25),
            SubtitleCue(text: "", start: 2, duration: 1),
            SubtitleCue(text: "Later", start: 3600.999, duration: 0),
            SubtitleCue(text: "invalid", start: .infinity, duration: 1)
        ])
        let expected = "1\n00:00:00,125 --> 00:00:01,375\nHello there\n\n2\n01:00:00,999 --> 01:00:01,049\nLater"
        precondition(result == expected, "SRT timestamps, numbering, whitespace cleanup, and invalid-cue filtering should be stable")
        precondition(SubtitleFormatter.srt([]).isEmpty, "An empty result should be a valid empty SRT body")
        print("MacNotch SRT subtitle formatting checks passed")
    }
}
