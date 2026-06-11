// Copyright (c) 2025 Proton AG
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
import ProtonCoreObservability

public final class DriveSDKAPIObservabilityMonitor {
    private let environment: ObservabilityEnvProtocol.Type

    public init(environment: ObservabilityEnvProtocol.Type = ObservabilityEnv.self) {
        self.environment = environment
    }

    public func reportApiRetrySucceeded() {
        let event = ObservabilityEvent(
            name: DriveSDKAPIObservabilityName.apiRetrySucceeded.rawValue,
            labels: [
                DriveSDKObservabilityLabelKey.volumeType.rawValue: DriveSDKObservabilityLabelValue.unknown.rawValue
            ],
            version: .v1
        )
        environment.report(event)
    }

    public func reportDebounce() {
        let event = ObservabilityEvent(
            name: DriveSDKAPIObservabilityName.debounce.rawValue,
            labels: [String: String](),
            version: .v1
        )
        environment.report(event)
    }
}

enum DriveSDKAPIObservabilityName: String {
    case apiRetrySucceeded = "drive_sdk_api_retry_succeeded_total"
    case debounce = "drive_sdk_debounce_total"
}
