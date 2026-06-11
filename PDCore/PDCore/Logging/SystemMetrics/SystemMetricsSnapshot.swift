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

/// Snapshot of both process-level and system-wide resource usage.
public struct SystemMetricsSnapshot: Encodable {

    enum CodingKeys: String, CodingKey {
        case ts, dt

        case residentMemoryMB = "mem_r"
        case virtualMemoryMB = "mem_v"

        case systemTotalMemoryMB = "smem_t"
        case systemUsedMemoryMB = "smem_u"
        case systemAvailableMemoryMB = "smem_a"

        case cpuUserSeconds = "cpu_u"
        case cpuSystemSeconds = "cpu_s"
        case systemCPUUsagePercent = "cpu_p"

        case processUptimeSeconds = "upt"
        case threadCount = "thr_c"

        case fpVolumeFreeGB = "dsk_f"
        case fpVolumeTotalGB = "dsk_t"
    }

    // -- Timestamp (set at collection time) --

    public let ts: Double
    public let dt: String

    // -- Process memory (MB) --

    public let residentMemoryMB: Double
    public let virtualMemoryMB: Double

    // -- Process CPU --

    public let cpuUserSeconds: Double
    public let cpuSystemSeconds: Double
    public let processUptimeSeconds: Double
    public let threadCount: Int

    public var cpuTotalSeconds: Double {
        cpuUserSeconds + cpuSystemSeconds
    }

    // -- System-wide memory (MB) --

    public let systemTotalMemoryMB: Double
    public let systemUsedMemoryMB: Double
    public let systemAvailableMemoryMB: Double

    // -- System-wide CPU --

    /// Overall CPU utilisation across all cores since the last sample, as a percentage.
    /// `nil` on the first sample (no delta available yet).
    public let systemCPUUsagePercent: Double?

    // -- FileProvider volume disk space (MB) --

    /// Free disk space on the FileProvider volume in MB.
    /// `nil` when no volume URL was provided or the query failed.
    public let fpVolumeFreeGB: Double?

    /// Total disk space on the FileProvider volume in MB.
    /// `nil` when no volume URL was provided or the query failed.
    public let fpVolumeTotalGB: Double?
}

extension SystemMetricsSnapshot: JSONLoggable {
    public var eventName: String {
        "metrics"
    }

    public var logLevel: LogLevel {
        .trace
    }

    public var domain: LogDomain {
        .metrics
    }
}
