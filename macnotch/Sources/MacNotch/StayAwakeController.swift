import Foundation
import Combine
import IOKit.pwr_mgt

@MainActor
final class StayAwakeController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var status = ""

    private var assertion: IOPMAssertionID = 0
    private var timer: Timer?
    private var endDate: Date?

    func start(for duration: TimeInterval) {
        stop(showStatus: false)
        var newAssertion: IOPMAssertionID = 0
        let assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        let timeoutAction = kIOPMAssertionTimeoutActionRelease as CFString
        let result = IOPMAssertionCreateWithDescription(
            assertionType,
            "MacNotch Stay Awake" as CFString,
            "Temporary work session" as CFString,
            "MacNotch is keeping the display and Mac awake." as CFString,
            nil,
            duration,
            timeoutAction,
            &newAssertion
        )
        guard result == kIOReturnSuccess else {
            status = "macOS could not keep the Mac awake."
            return
        }

        assertion = newAssertion
        endDate = Date().addingTimeInterval(duration)
        isActive = true
        status = "Stay Awake is on."
        updateRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateRemaining() }
        }
    }

    func stop(showStatus: Bool = true) {
        timer?.invalidate()
        timer = nil
        if assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
        endDate = nil
        isActive = false
        secondsRemaining = 0
        if showStatus { status = "Stay Awake is off." }
    }

    private func updateRemaining() {
        guard let endDate else { return }
        secondsRemaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if secondsRemaining == 0 { stop() }
    }
}
