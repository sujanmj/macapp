import AppKit
import Darwin
import Foundation
import IOKit.ps
import MachO

struct MacBatteryStatus: Equatable {
    let percent: Int
    let isCharging: Bool
    let minutesRemaining: Int?

    var displayDetail: String {
        if isCharging { return "Charging" }
        guard let minutesRemaining else { return "On battery" }
        let hours = minutesRemaining / 60
        let minutes = minutesRemaining % 60
        if hours > 0 { return "About \(hours)h \(minutes)m remaining" }
        return "About \(minutes)m remaining"
    }

    static func make(currentCapacity: Int?, maximumCapacity: Int?, isCharging: Bool, minutesRemaining: Int?) -> MacBatteryStatus? {
        guard let currentCapacity, let maximumCapacity, maximumCapacity > 0, currentCapacity >= 0 else { return nil }
        let boundedCapacity = min(currentCapacity, maximumCapacity)
        let percent = Int((Double(boundedCapacity) / Double(maximumCapacity) * 100).rounded())
        let remaining = minutesRemaining.flatMap { (0..<10_080).contains($0) ? $0 : nil }
        return MacBatteryStatus(percent: min(100, max(0, percent)), isCharging: isCharging, minutesRemaining: remaining)
    }
}

struct MacMetrics {
    var cpuPercent: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    var uploadBytesPerSecond: UInt64 = 0
    var downloadBytesPerSecond: UInt64 = 0
    var topProcess: String?
    var topProcessBytes: UInt64?
    var diskFree: UInt64 = 0
    var diskTotal: UInt64 = 0
    var battery: MacBatteryStatus?
    var sampledAt = Date()
}

/// Lightweight local sampling for the MacNotch Widgets view. No data leaves this Mac.
final class SystemSampler {
    private var previousCPU: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var previousNetwork: (received: UInt64, sent: UInt64, date: Date)?
    private var lastProcessSample = Date.distantPast
    private var cachedTopProcess: (name: String, bytes: UInt64)?

    func sample() -> MacMetrics {
        var metrics = MacMetrics()
        metrics.cpuPercent = sampleCPU()
        metrics.memoryUsed = sampleMemory()
        let network = sampleNetwork()
        if let previousNetwork {
            let elapsed = max(0.1, Date().timeIntervalSince(previousNetwork.date))
            if network.received >= previousNetwork.received {
                metrics.downloadBytesPerSecond = UInt64(Double(network.received - previousNetwork.received) / elapsed)
            }
            if network.sent >= previousNetwork.sent {
                metrics.uploadBytesPerSecond = UInt64(Double(network.sent - previousNetwork.sent) / elapsed)
            }
        }
        previousNetwork = (network.received, network.sent, Date())
        if Date().timeIntervalSince(lastProcessSample) >= 10 {
            cachedTopProcess = sampleTopProcess()
            lastProcessSample = Date()
        }
        metrics.topProcess = cachedTopProcess?.name
        metrics.topProcessBytes = cachedTopProcess?.bytes
        if let values = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            metrics.diskFree = (values[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
            metrics.diskTotal = (values[.systemSize] as? NSNumber)?.uint64Value ?? 0
        }
        metrics.battery = sampleBattery()
        metrics.sampledAt = Date()
        return metrics
    }

    private func sampleBattery() -> MacBatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let unmanaged = IOPSGetPowerSourceDescription(info, source),
                  let details = unmanaged.takeUnretainedValue() as? [String: Any],
                  details[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType as String else { continue }
            let current = (details[kIOPSCurrentCapacityKey as String] as? NSNumber)?.intValue
            let maximum = (details[kIOPSMaxCapacityKey as String] as? NSNumber)?.intValue
            let charging = (details[kIOPSIsChargingKey as String] as? NSNumber)?.boolValue ?? false
            let minutes = (details[kIOPSTimeToEmptyKey as String] as? NSNumber)?.intValue
            return MacBatteryStatus.make(currentCapacity: current, maximumCapacity: maximum,
                                         isCharging: charging, minutesRemaining: minutes)
        }
        return nil
    }

    private func sampleCPU() -> Double {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let current = (user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        defer { previousCPU = current }
        guard let previousCPU else { return 0 }
        let user = current.user &- previousCPU.user
        let system = current.system &- previousCPU.system
        let idle = current.idle &- previousCPU.idle
        let nice = current.nice &- previousCPU.nice
        let total = UInt64(user) + UInt64(system) + UInt64(idle) + UInt64(nice)
        guard total > 0 else { return 0 }
        return min(100, max(0, Double(UInt64(user) + UInt64(system) + UInt64(nice)) * 100 / Double(total)))
    }

    private func sampleMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(vm_kernel_page_size)
        let usedPages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return usedPages * pageSize
    }

    private func sampleNetwork() -> (received: UInt64, sent: UInt64) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return (0, 0) }
        defer { freeifaddrs(head) }
        var interfaces: [(name: String, received: UInt64, sent: UInt64)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            guard let namePointer = item.pointee.ifa_name,
                  let dataPointer = item.pointee.ifa_data,
                  item.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: namePointer)
            guard name.hasPrefix("en"),
                  item.pointee.ifa_flags & UInt32(IFF_UP) != 0 else { continue }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            interfaces.append((name, UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes)))
        }
        let chosen = interfaces.first(where: { $0.name == "en0" }) ?? interfaces.sorted(by: { $0.name < $1.name }).first
        return (chosen?.received ?? 0, chosen?.sent ?? 0)
    }

    private func sampleTopProcess() -> (name: String, bytes: UInt64)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-A", "-o", "rss=", "-o", "comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: output, encoding: .utf8) else { return nil }
            let candidates = text.split(separator: "\n").compactMap { line -> (String, UInt64)? in
                let parts = line.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
                guard parts.count == 2, let kibibytes = UInt64(parts[0]), kibibytes > 0 else { return nil }
                let command = String(parts[1])
                let name = URL(fileURLWithPath: command).lastPathComponent
                guard !name.isEmpty else { return nil }
                return (name, kibibytes * 1024)
            }
            guard let largest = candidates.max(by: { $0.1 < $1.1 }) else { return nil }
            return (largest.0, largest.1)
        } catch { return nil }
    }
}
