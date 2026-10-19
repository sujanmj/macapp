import Foundation

@main
struct TeleprompterPlaybackTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        var playback = TeleprompterPlayback(pointsPerSecond: 30)
        playback.start(at: start)
        check(playback.offset(at: start.addingTimeInterval(2)) == 60,
              "running offset follows elapsed time and configured speed")
        playback.pause(at: start.addingTimeInterval(2))
        check(!playback.isRunning, "pause stops the clock")
        check(playback.offset(at: start.addingTimeInterval(20)) == 60,
              "paused offset remains fixed")
        playback.start(at: start.addingTimeInterval(20))
        check(playback.offset(at: start.addingTimeInterval(21)) == 90,
              "resume continues from the paused offset")
        playback.setSpeed(60, at: start.addingTimeInterval(21))
        check(playback.offset(at: start.addingTimeInterval(21)) == 90,
              "changing speed preserves the current scroll position")
        check(playback.offset(at: start.addingTimeInterval(22)) == 150,
              "new speed applies only after the change")
        playback.setSpeed(.infinity, at: start.addingTimeInterval(22))
        check(playback.pointsPerSecond == 45 && playback.offset(at: start.addingTimeInterval(22)) == 150,
              "non-finite speed falls back without moving the script")
        check(playback.offset(at: start.addingTimeInterval(23)) == 195,
              "sanitized fallback speed is used for later scrolling")
        playback.reset()
        check(!playback.isRunning && playback.offset(at: start) == 0,
              "reset returns to the beginning")
        print("MacNotch teleprompter playback checks passed")
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
}
