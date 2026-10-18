import Foundation

enum FocusPhase: String, Equatable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var duration: Int {
        switch self {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}

struct PomodoroCycle {
    private(set) var completedFocuses = 0

    mutating func advance(after phase: FocusPhase) -> FocusPhase {
        switch phase {
        case .focus:
            completedFocuses += 1
            return completedFocuses.isMultiple(of: 4) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }
}
