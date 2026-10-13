import Foundation
import Darwin

/// Public, non-privileged telemetry. Rates are differences between samples:
/// the first sample intentionally has no CPU/network usage percentages.
struct LiveMetrics {
    let sampledAt: Date
    let cpuPercent: Double?
    let uploadBytesPerSecond: Double?
    let downloadBytesPerSecond: Double?
    let batteryPercent: Int?
    let batteryState: String
    let powerSource: String
    let thermalState: String

    static let initial = LiveMetrics(
        sampledAt: .now, cpuPercent: nil, uploadBytesPerSecond: nil,
        downloadBytesPerSecond: nil, batteryPercent: nil,
        batteryState: "Unknown", powerSource: "Unknown", thermalState: "Unknown"
    )
}

struct PerformancePoint: Identifiable {
    let date: Date
    let cpuPercent: Double
    let downloadMiBs: Double
    let uploadMiBs: Double
    var id: Date { date }
}

/// Deliberately avoids privileged/private CPU sensor, GPU and temperature APIs.
final class AdvancedSystemSampler {
    private var previousTime: Date?
    private var previousCPUTicks: [UInt64]?
    private var previousInterfaceBytes: (down: UInt64, up: UInt64)?

    func sample() -> LiveMetrics {
        let now = Date()
        let elapsed = previousTime.map { now.timeIntervalSince($0) } ?? 0
        let newTicks = readCPUTicks()
        let network = readNetworkBytes()

        var cpuUsage: Double?
        if let before = previousCPUTicks, let after = newTicks, after.count == before.count {
            let differences = zip(after, before).map { (current, old) in current >= old ? current - old : 0 }
            let total = differences.reduce(UInt64(0), +)
            if total > 0 {
                // host_cpu_load_info: user, system, idle, nice
                cpuUsage = min(100, max(0, (Double(differences[0] + differences[1] + differences[3]) / Double(total)) * 100))
            }
        }

        var down: Double?
        var up: Double?
        if elapsed > 0.5, let before = previousInterfaceBytes, let after = network,
           after.down >= before.down, after.up >= before.up {
            down = Double(after.down - before.down) / elapsed
            up = Double(after.up - before.up) / elapsed
        }

        previousCPUTicks = newTicks
        previousInterfaceBytes = network
        previousTime = now

        let battery = readBattery()
        return LiveMetrics(
            sampledAt: now, cpuPercent: cpuUsage,
            uploadBytesPerSecond: up, downloadBytesPerSecond: down,
            batteryPercent: battery.percent, batteryState: battery.state,
            powerSource: battery.source, thermalState: readThermalState()
        )
    }

    private func readCPUTicks() -> [UInt64]? {
        var value = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let status = withUnsafeMutablePointer(to: &value) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        return [
            UInt64(value.cpu_ticks.0), UInt64(value.cpu_ticks.1),
            UInt64(value.cpu_ticks.2), UInt64(value.cpu_ticks.3)
        ]
    }

    private func readNetworkBytes() -> (down: UInt64, up: UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(first) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var visited = Set<String>()
        var node: UnsafeMutablePointer<ifaddrs>? = first
        while let current = node {
            let entry = current.pointee
            if let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
               let data = entry.ifa_data {
                let name = String(cString: entry.ifa_name)
                // Hardware interfaces only. Avoid double counting traffic
                // mirrored through utun, bridge, loopback and virtual devices.
                if name.hasPrefix("en"), !visited.contains(name) {
                    visited.insert(name)
                    let info = data.assumingMemoryBound(to: if_data.self).pointee
                    received += UInt64(info.ifi_ibytes)
                    sent += UInt64(info.ifi_obytes)
                }
            }
            node = entry.ifa_next
        }
        return (received, sent)
    }

    private func readThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Elevated"
        case .serious: return "High"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private func readBattery() -> (percent: Int?, state: String, source: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let output = String(data: bytes, encoding: .utf8) else {
                return (nil, "Unavailable", "Unknown")
            }
            let source = output.localizedCaseInsensitiveContains("AC Power") ? "Power adapter" : "Battery"
            let status: String
            if output.localizedCaseInsensitiveContains("discharging") { status = "Discharging" }
            else if output.localizedCaseInsensitiveContains("charged") { status = "Charged" }
            else if output.localizedCaseInsensitiveContains("charging") { status = "Charging" }
            else { status = "Unknown" }
            let percentage: Int?
            if let match = output.range(of: #"[0-9]{1,3}%"#, options: .regularExpression) {
                percentage = Int(output[match].dropLast())
            } else { percentage = nil }
            return (percentage, status, source)
        } catch {
            return (nil, "Unavailable", "Unknown")
        }
    }
}
