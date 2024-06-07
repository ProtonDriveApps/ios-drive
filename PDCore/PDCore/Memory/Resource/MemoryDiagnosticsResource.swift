// Copyright (c) 2024 Proton AG
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

public struct MemoryDiagnostics {
    public let usedMB: Double
    public let totalMB: Double
}

public protocol MemoryDiagnosticsResource {
    func getDiagnostics() throws -> MemoryDiagnostics
}

enum MemoryDiagnosticsResourceError: Error {
    case diagnosticsUnavailable
}

public final class DeviceMemoryDiagnosticsResource: MemoryDiagnosticsResource {
    private let bytesInMB: Double = 1024 * 1024

    public init() {}

    public func getDiagnostics() throws -> MemoryDiagnostics {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            throw MemoryDiagnosticsResourceError.diagnosticsUnavailable
        }

        let usedMB = Double(taskInfo.phys_footprint) / bytesInMB
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / bytesInMB
        return MemoryDiagnostics(usedMB: usedMB, totalMB: totalMB)
    }
}
