// Copyright (c) 2026 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Foundation
import Darwin

/// Collects process-level and system-wide metrics using Mach kernel APIs.
///
/// Because system CPU usage is derived from the *delta* between two tick
/// samples, the collector is a class that retains the previous sample.
/// Create one instance and call `collect()` repeatedly.
public final class SystemMetricsCollector {

    private var previousCPUTicks: CPUTicks?
    private let volumeURL: URL?

    /// - Parameter volumeURL: A URL on the FileProvider volume whose free disk space should be tracked.
    ///   Pass `nil` to skip disk-space collection.
    public init(volumeURL: URL? = nil) {
        self.volumeURL = volumeURL
    }

    public func collect() -> SystemMetricsSnapshot? {
        guard let processMemory = Self.collectProcessMemory(),
              let processCPU = Self.collectProcessCPU() else {
            return nil
        }

        let now = Date()
        let systemMemory = Self.collectSystemMemory()
        let (systemCPUUsage, currentTicks) = collectSystemCPUUsage()
        previousCPUTicks = currentTicks
        let volumeDiskSpace = collectVolumeDiskSpace()
        let threadCount = Self.collectThreadCount()

        return SystemMetricsSnapshot(
            ts: now.timeIntervalSince1970,
            dt: now.description,
            residentMemoryMB: Self.bytesToMB(processMemory.resident),
            virtualMemoryMB: Self.bytesToMB(processMemory.virtual),
            cpuUserSeconds: processCPU.user,
            cpuSystemSeconds: processCPU.system,
            processUptimeSeconds: ProcessInfo.processInfo.systemUptime,
            threadCount: threadCount,
            systemTotalMemoryMB: Self.bytesToMB(systemMemory.total),
            systemUsedMemoryMB: Self.bytesToMB(systemMemory.used),
            systemAvailableMemoryMB: Self.bytesToMB(systemMemory.available),
            systemCPUUsagePercent: systemCPUUsage.map { ($0 * 1000).rounded() / 10 },
            fpVolumeFreeGB: Self.bytesToGB(volumeDiskSpace?.free ?? 0),
            fpVolumeTotalGB: Self.bytesToGB(volumeDiskSpace?.total ?? 0),
        )
    }

    // MARK: - Process memory (MACH_TASK_BASIC_INFO)

    private static func collectProcessMemory() -> (resident: UInt64, virtual: UInt64)? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rawPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return (resident: UInt64(info.resident_size), virtual: UInt64(info.virtual_size))
    }

    // MARK: - Process CPU (TASK_THREAD_TIMES_INFO)

    private static func collectProcessCPU() -> (user: Double, system: Double)? {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), rawPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let user = timevalToSeconds(seconds: info.user_time.seconds, microseconds: info.user_time.microseconds)
        let system = timevalToSeconds(seconds: info.system_time.seconds, microseconds: info.system_time.microseconds)
        return (user: user, system: system)
    }

    // MARK: - System memory (HOST_VM_INFO64)

    private static func collectSystemMemory() -> (total: UInt64, used: UInt64, available: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(vm_kernel_page_size)

        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rawPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (total: total, used: 0, available: 0)
        }

        let active = UInt64(info.active_count) * pageSize
        let wired = UInt64(info.wire_count) * pageSize
        let compressed = UInt64(info.compressor_page_count) * pageSize
        let free = UInt64(info.free_count) * pageSize
        let inactive = UInt64(info.inactive_count) * pageSize

        let used = active + wired + compressed
        let available = free + inactive

        return (total: total, used: used, available: available)
    }

    // MARK: - System CPU (HOST_CPU_LOAD_INFO) — delta-based

    struct CPUTicks {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64

        var total: UInt64 { user + system + idle + nice }
    }

    private func collectSystemCPUUsage() -> (usage: Double?, ticks: CPUTicks?) {
        guard let current = Self.collectCPUTicks() else { return (nil, nil) }

        guard let previous = previousCPUTicks else {
            return (nil, current)
        }

        let deltaTotal = Double(current.total &- previous.total)
        guard deltaTotal > 0 else { return (nil, current) }

        let deltaIdle = Double(current.idle &- previous.idle)
        let usage = (deltaTotal - deltaIdle) / deltaTotal

        return (usage, current)
    }

    private static func collectCPUTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rawPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    // MARK: - Thread count (task_threads)

    private static func collectThreadCount() -> Int {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        if result == KERN_SUCCESS, let list = threadList {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: list),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_act_t>.size)
            )
        }
        return Int(threadCount)
    }

    // MARK: - Volume disk space

    private func collectVolumeDiskSpace() -> (free: Int64, total: Int64)? {
        guard let volumeURL else { return nil }
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? volumeURL.resourceValues(forKeys: keys),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else {
            return nil
        }
        return (free: free, total: Int64(total))
    }

    // MARK: - Helpers

    private static func timevalToSeconds(seconds: Int32, microseconds: Int32) -> Double {
        Double(seconds) + Double(microseconds) / 1_000_000
    }

    private static func bytesToMB(_ bytes: UInt64) -> Double {
        Double(bytes) / 1_048_576
    }

    private static func bytesToGB(_ bytes: Int64) -> Double {
        Double(bytes) / 10_615_783_424
    }
}
