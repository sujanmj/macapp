import Foundation
import Darwin

struct SystemSnapshot {
    let totalMemory: UInt64
    let usedMemory: UInt64
    let totalDisk: UInt64
    let freeDisk: UInt64

    var memoryRatio: Double {
        totalMemory > 0 ? min(1, Double(usedMemory) / Double(totalMemory)) : 0
    }
    var diskRatio: Double {
        totalDisk > 0 ? min(1, Double(totalDisk - freeDisk) / Double(totalDisk)) : 0
    }
    static func bytes(_ amount: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: amount), countStyle: .binary)
    }

    static func read() -> SystemSnapshot {
        let total = ProcessInfo.processInfo.physicalMemory
        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kernResult = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        // Approximation: active + wired + compressed. Inactive and cached pages
        // are potentially reclaimable. macOS Activity Monitor may differ.
        let pages = kernResult == KERN_SUCCESS
          ? UInt64(vm.active_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)
          : 0
        let used = min(total, pages * UInt64(vm_kernel_page_size))
        let disk = (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())) ?? [:]
        let totalDisk = (disk[.systemSize] as? NSNumber)?.uint64Value ?? 0
        let freeDisk = (disk[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        return SystemSnapshot(totalMemory: total, usedMemory: used, totalDisk: totalDisk, freeDisk: freeDisk)
    }
}
