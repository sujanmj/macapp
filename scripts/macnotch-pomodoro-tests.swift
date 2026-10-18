import Foundation

@main
struct PomodoroCycleTests {
    static func main() {
        var cycle = PomodoroCycle()
        check(FocusPhase.focus.duration == 1_500, "focus phase is 25 minutes")
        check(FocusPhase.shortBreak.duration == 300, "short break is 5 minutes")
        check(FocusPhase.longBreak.duration == 900, "long break is 15 minutes")
        check(cycle.advance(after: .focus) == .shortBreak, "first focus advances to short break")
        check(cycle.advance(after: .shortBreak) == .focus, "short break returns to focus")
        check(cycle.advance(after: .focus) == .shortBreak, "second focus advances to short break")
        check(cycle.advance(after: .focus) == .shortBreak, "third focus advances to short break")
        check(cycle.advance(after: .focus) == .longBreak, "fourth focus advances to long break")
        check(cycle.completedFocuses == 4, "completed focus count is retained")
        check(cycle.advance(after: .longBreak) == .focus, "long break returns to focus")
        print("MacNotch Pomodoro cycle checks passed")
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
}
