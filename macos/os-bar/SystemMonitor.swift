import Foundation
import Darwin

// MARK: - Protocol

/// Abstract interface for fetching CPU and memory percentages.
/// Allows injection of mock providers for testing.
protocol SystemInfoProviding {
    func getCPUPercent() -> Double
    func getMEMPercent() -> Double
}

// MARK: - Real Provider

/// Fetches live system metrics using host-level Mach APIs.
final class RealSystemInfoProvider: SystemInfoProviding {
    func getCPUPercent() -> Double {
        var processorInfo: processor_info_array_t?
        var processorMsgCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorMsgCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            return 0
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(processorMsgCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0
        var totalNice: Double = 0

        let cpuLoadPtr = info.withMemoryRebound(
            to: integer_t.self,
            capacity: Int(processorMsgCount)
        ) { $0 }

        for i in 0..<Int(processorCount) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser   += Double(cpuLoadPtr[offset + Int(CPU_STATE_USER)])
            totalSystem += Double(cpuLoadPtr[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle   += Double(cpuLoadPtr[offset + Int(CPU_STATE_IDLE)])
            totalNice   += Double(cpuLoadPtr[offset + Int(CPU_STATE_NICE)])
        }

        let total = totalUser + totalSystem + totalIdle + totalNice
        let used  = totalUser + totalSystem + totalNice

        guard total > 0 else { return 0 }
        return (used / total) * 100.0
    }

    func getMEMPercent() -> Double {
        // Total physical memory via sysctl(HW_MEMSIZE)
        var totalMem: UInt64 = 0
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var len = MemoryLayout<UInt64>.size
        sysctl(&mib, 2, &totalMem, &len, nil, 0)
        let totalMemory = Double(totalMem)

        // VM statistics via host_statistics64
        var vmInfo = vm_statistics64()
        var vmCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let vmResult = withUnsafeMutablePointer(to: &vmInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }

        guard vmResult == KERN_SUCCESS, totalMemory > 0 else { return 0 }

        let pageSize = Double(vm_kernel_page_size)
        let usedMemory = Double(vmInfo.active_count + vmInfo.wire_count) * pageSize

        return (usedMemory / totalMemory) * 100.0
    }
}

// MARK: - SystemMonitor

final class SystemMonitor: ObservableObject {
    @Published var cpuPercent: Double = 0
    @Published var memPercent: Double = 0

    private let provider: SystemInfoProviding
    private var timer: Timer?

    init(provider: SystemInfoProviding = RealSystemInfoProvider()) {
        self.provider = provider
        fetchMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.fetchMetrics()
        }
    }

    func start() {
        // Timer already started in init; no-op for compatibility
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func fetchMetrics() {
        cpuPercent = provider.getCPUPercent()
        memPercent = provider.getMEMPercent()
    }
}
