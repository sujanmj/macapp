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
        print("MacNotch sampler checks passed")
    }
}
