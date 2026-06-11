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

/// Provides iOS version and hardware identifier
public struct DeviceInfo {
    public init() {}

    /// A formatted string containing OS version and hardware identifier.
    /// 
    /// Format: "os: <version>, hardwareIdentifier: <identifier>"
    /// Example: "os: 17.2.1, hardwareIdentifier: iPhone16,2"
    public var info: String {
        "os: \(iOSVersion()), hardwareIdentifier: \(hardwareIdentifier())"
    }

    /// Returns the hardware identifier of the device.
    /// 
    /// - Returns: For simulators, returns "simulator <model>" if available, otherwise "iOS Simulator".
    ///            For physical devices, returns the device model identifier (e.g., "iPhone16,2").
    ///            Returns "Unknown" if the identifier cannot be determined.
    private func hardwareIdentifier() -> String {
        #if targetEnvironment(simulator)
        // Prefer Xcode-provided simulator model identifier when available
        if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simModel.isEmpty {
            return "simulator \(simModel)" // e.g., "iPhone16,2"
        }
        return "iOS Simulator"
        #else
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            return "Unknown"
        }
        
        let data = Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN))
        if let identifier = String(bytes: data, encoding: .ascii) {
            return identifier.trimmingCharacters(in: .controlCharacters)
        }
        return "Unknown"
        #endif
    }

    /// - Returns: "17.2.1"
    private func iOSVersion() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }
}
