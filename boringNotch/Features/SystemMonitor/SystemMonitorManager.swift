//
//  SystemMonitorManager.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Combine
import Defaults
import Foundation
import os

/// Centralized system monitor data manager.
class SystemMonitorManager: ObservableObject {

    static let shared = SystemMonitorManager()

    private let logger = Logger(subsystem: "com.dynanotch", category: "SystemMonitor")

    // MARK: - Published State

    @Published var cpuUsage: Double = 0.0       // 0–100%
    @Published var cpuHistory: [Double] = []    // last 15 samples (30s at 2s interval)
    @Published var ramUsedGB: Double = 0.0
    @Published var ramTotalGB: Double = 0.0
    @Published var networkUpSpeed: UInt64 = 0    // bytes/sec
    @Published var networkDownSpeed: UInt64 = 0  // bytes/sec
    @Published var diskUsedGB: Double = 0.0
    @Published var diskTotalGB: Double = 0.0
    @Published var cpuTemperature: Double? = nil // stub for now

    // MARK: - Computed

    var isActive: Bool {
        Defaults[.enableSystemMonitor]
    }

    var ramUsagePercent: Double {
        guard ramTotalGB > 0 else { return 0 }
        return (ramUsedGB / ramTotalGB) * 100.0
    }

    var diskUsagePercent: Double {
        guard diskTotalGB > 0 else { return 0 }
        return (diskUsedGB / diskTotalGB) * 100.0
    }

    // MARK: - Private

    private var timer: AnyCancellable?
    private var enabledCancellable: AnyCancellable?

    // CPU tick tracking
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    // Network byte tracking
    private var previousNetBytes: (sent: UInt64, received: UInt64)?
    private var previousNetTimestamp: Date?

    // MARK: - Init

    private init() {
        // Fetch RAM total once
        ramTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0

        // React to enable/disable
        enabledCancellable = Defaults.publisher(.enableSystemMonitor)
            .sink { [weak self] change in
                if change.newValue {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }

        if Defaults[.enableSystemMonitor] {
            startMonitoring()
        }
    }

    // MARK: - Monitoring Lifecycle

    private func startMonitoring() {
        logger.info("[SYSMON] start monitoring")
        previousCPUTicks = nil
        previousNetBytes = nil
        previousNetTimestamp = nil

        // Immediate first sample
        collectMetrics()

        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.collectMetrics()
            }
    }

    private func stopMonitoring() {
        logger.info("[SYSMON] stop monitoring")
        timer?.cancel()
        timer = nil
    }

    // MARK: - Data Collection

    private func collectMetrics() {
        if Defaults[.showCPUUsage] {
            updateCPU()
        }
        if Defaults[.showRAMUsage] {
            updateRAM()
        }
        if Defaults[.showNetworkSpeed] {
            updateNetwork()
        }
        if Defaults[.showDiskUsage] {
            updateDisk()
        }
        if Defaults[.showCPUTemperature] {
            // Temperature: SMC is complex, stub for now
            cpuTemperature = nil
        }
    }

    // MARK: - CPU

    private func updateCPU() {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &loadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            logger.warning("[SYSMON] CPU stats failed: \(result)")
            return
        }

        let user = loadInfo.cpu_ticks.0
        let system = loadInfo.cpu_ticks.1
        let idle = loadInfo.cpu_ticks.2
        let nice = loadInfo.cpu_ticks.3

        if let prev = previousCPUTicks {
            let dUser = user - prev.user
            let dSystem = system - prev.system
            let dIdle = idle - prev.idle
            let dNice = nice - prev.nice
            let totalDelta = dUser + dSystem + dIdle + dNice

            if totalDelta > 0 {
                let used = Double(dUser + dSystem + dNice)
                cpuUsage = (used / Double(totalDelta)) * 100.0
                cpuHistory.append(cpuUsage)
                if cpuHistory.count > 15 {
                    cpuHistory.removeFirst(cpuHistory.count - 15)
                }
            }
        }

        previousCPUTicks = (user, system, idle, nice)
    }

    // MARK: - RAM

    private func updateRAM() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            logger.warning("[SYSMON] RAM stats failed: \(result)")
            return
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        // speculative and inactive are "available"
        let used = active + wired + compressed

        ramUsedGB = Double(used) / 1_073_741_824.0
    }

    // MARK: - Network

    private func updateNetwork() {
        var (totalSent, totalReceived): (UInt64, UInt64) = (0, 0)
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            logger.warning("[SYSMON] getifaddrs failed")
            return
        }

        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = ptr {
            let name = String(cString: addr.pointee.ifa_name)
            // Only count physical interfaces (en*, lo*)
            if name.hasPrefix("en") || name.hasPrefix("lo") {
                if addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    let data = unsafeBitCast(addr.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                    totalSent += UInt64(data.pointee.ifi_obytes)
                    totalReceived += UInt64(data.pointee.ifi_ibytes)
                }
            }
            ptr = addr.pointee.ifa_next
        }

        let now = Date()

        if let prevBytes = previousNetBytes, let prevTime = previousNetTimestamp {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                let sentDelta = totalSent >= prevBytes.sent ? totalSent - prevBytes.sent : 0
                let receivedDelta = totalReceived >= prevBytes.received ? totalReceived - prevBytes.received : 0
                networkUpSpeed = UInt64(Double(sentDelta) / elapsed)
                networkDownSpeed = UInt64(Double(receivedDelta) / elapsed)
            }
        }

        previousNetBytes = (totalSent, totalReceived)
        previousNetTimestamp = now
    }

    // MARK: - Disk

    private func updateDisk() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let totalSize = attrs[.systemSize] as? UInt64,
               let freeSize = attrs[.systemFreeSize] as? UInt64 {
                diskTotalGB = Double(totalSize) / 1_073_741_824.0
                diskUsedGB = Double(totalSize - freeSize) / 1_073_741_824.0
            }
        } catch {
            logger.warning("[SYSMON] disk stats failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Formatting Helpers

    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB/s", Double(bytes) / 1_073_741_824.0)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB/s", Double(bytes) / 1_048_576.0)
        } else if bytes >= 1024 {
            return String(format: "%.1f KB/s", Double(bytes) / 1024.0)
        } else {
            return "\(bytes) B/s"
        }
    }
}
