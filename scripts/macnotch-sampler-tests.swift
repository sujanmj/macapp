import Foundation

@main
struct MacNotchSamplerTests {
    static func main() {
        let sampler = SystemSampler()
        let first = sampler.sample()
        Thread.sleep(forTimeInterval: 0.25)
        let second = sampler.sample()

        precondition(first.memoryTotal > 0, "Physical memory total should be available")
        precondition(second.memoryUsed > 0 && second.memoryUsed <= second.memoryTotal, "Used memory should fit within physical memory")
        precondition(second.cpuPercent.isFinite && (0...100).contains(second.cpuPercent), "CPU percentage should stay in range")
        precondition(second.diskTotal > 0 && second.diskFree <= second.diskTotal, "Filesystem capacity should be valid")
        precondition(second.sampledAt >= first.sampledAt, "Samples should have monotonic timestamps")
        precondition(second.topProcess != nil && (second.topProcessBytes ?? 0) > 0, "Top resident-memory process should be found")
        precondition(second.battery.map { (0...100).contains($0.percent) } ?? true, "Battery charge should be a percentage when a battery is present")
        precondition(MacBatteryStatus.make(currentCapacity: 80, maximumCapacity: 100, isCharging: true, minutesRemaining: 45) ==
                     MacBatteryStatus(percent: 80, isCharging: true, minutesRemaining: 45), "Battery values should normalize into a stable status")
        precondition(MacBatteryStatus.make(currentCapacity: 120, maximumCapacity: 100, isCharging: false, minutesRemaining: -1)?.percent == 100,
                     "Battery percentage should be capped and unknown times omitted")
        precondition(MacBatteryStatus.make(currentCapacity: 80, maximumCapacity: 0, isCharging: false, minutesRemaining: nil) == nil,
                     "Invalid battery capacity should not produce a status")
        print("MacNotch sampler checks passed")
    }
}
