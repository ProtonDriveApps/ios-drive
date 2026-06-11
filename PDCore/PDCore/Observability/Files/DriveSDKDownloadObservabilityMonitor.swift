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

public actor DriveSDKDownloadObservabilityMonitor {
    private let environment: ObservabilityEnvProtocol.Type
    private let dateResource: DateResource
    private var lastReportedDate: Date?

    public init(
        environment: ObservabilityEnvProtocol.Type = ObservabilityEnv.self,
        dateResource: DateResource = PlatformCurrentDateResource()
    ) {
        self.environment = environment
        self.dateResource = dateResource
    }

    public func reportSuccess(volumeType: String, status: String) {
        assert(["success", "failure"].contains(status))
        let event = ObservabilityEvent(
            name: DriveSDKDownloadObservabilityName.successRateTotal.rawValue,
            labels: [
                DriveSDKObservabilityLabelKey.volumeType.rawValue: volumeType,
                DriveSDKObservabilityLabelKey.status.rawValue: status
            ],
            version: .v1
        )
        environment.report(event)
    }

    public func reportError(volumeType: String, type: String) {
        let event = ObservabilityEvent(
            name: DriveSDKDownloadObservabilityName.errorsTotal.rawValue,
            labels: [
                DriveSDKObservabilityLabelKey.volumeType.rawValue: volumeType,
                DriveSDKObservabilityLabelKey.type.rawValue: type
            ],
            version: .v1
        )
        environment.report(event)
    }

    public func reportClaimedFileSizeOnError(size: Int) {
        let event = ObservabilityEvent(
            name: DriveSDKDownloadObservabilityName.errorFileSizeHistogram.rawValue,
            value: size,
            labels: [String: String](),
            version: .v1
        )
        environment.report(event)
    }

    public func reportTransferSizeOnError(size: Int) {
        let event = ObservabilityEvent(
            name: DriveSDKDownloadObservabilityName.errorTransferSizeHistogram.rawValue,
            value: size,
            labels: [String: String](),
            version: .v1
        )
        environment.report(event)
    }

    public func reportErroringUser(volumeType: String, userPlan: String) {
        let current = dateResource.getDate()
        guard isAllowedToReportErroringUser(current: current) else { return }
        lastReportedDate = current
        let event = ObservabilityEvent(
            name: DriveSDKDownloadObservabilityName.erroringUsersTotal.rawValue,
            labels: [
                DriveSDKObservabilityLabelKey.volumeType.rawValue: volumeType,
                DriveSDKObservabilityLabelKey.userPlan.rawValue: userPlan
            ],
            version: .v1
        )
        environment.report(event)
    }

    private func isAllowedToReportErroringUser(current: Date) -> Bool {
        guard let lastReportedDate else { return true }
        let interval = lastReportedDate.distance(to: current)
        return interval > 5.minutes
    }
}

enum DriveSDKDownloadObservabilityName: String {
    case erroringUsersTotal = "drive_sdk_download_erroring_users_total"
    case errorTransferSizeHistogram = "drive_sdk_download_errors_transfer_size_histogram"
    case errorFileSizeHistogram = "drive_sdk_download_errors_file_size_histogram"
    case errorsTotal = "drive_sdk_download_errors_total"
    case successRateTotal = "drive_sdk_download_success_rate_total"
}
