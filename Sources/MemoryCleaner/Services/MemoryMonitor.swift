import Foundation
import Darwin

/// Reads system and process memory stats via Mach APIs (macOS).
enum MemoryMonitor {

    static func snapshot() -> MemorySnapshot {
        let pageSize = UInt64(vm_kernel_page_size)
        let vm = vmStatistics()
        let total = ProcessInfo.processInfo.physicalMemory

        let free = UInt64(vm.free_count) * pageSize
        let active = UInt64(vm.active_count) * pageSize
        let inactive = UInt64(vm.inactive_count) * pageSize
        let wired = UInt64(vm.wire_count) * pageSize
        let speculative = UInt64(vm.speculative_count) * pageSize
        let compressed = UInt64(vm.compressor_page_count) * pageSize
        let purgeable = UInt64(vm.purgeable_count) * pageSize

        // Available ≈ free + speculative + inactive + purgeable (reclaimable under pressure).
        let freeish = free + speculative + inactive + purgeable
        // Used ≈ total − free − speculative (still "held", but inactive is part of working set history).
        let used = total > (free + speculative) ? total - (free + speculative) : active + inactive + wired + compressed

        return MemorySnapshot(
            totalBytes: total,
            usedBytes: min(used, total),
            freeBytes: min(freeish, total),
            wiredBytes: wired,
            inactiveBytes: inactive,
            activeBytes: active,
            compressedBytes: compressed,
            purgeableBytes: purgeable,
            appResidentBytes: appResidentSize(),
            timestamp: Date()
        )
    }

    // MARK: - Mach helpers

    private static func vmStatistics() -> vm_statistics64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        if result != KERN_SUCCESS {
            return vm_statistics64()
        }
        return stats
    }

    private static func appResidentSize() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }
}
