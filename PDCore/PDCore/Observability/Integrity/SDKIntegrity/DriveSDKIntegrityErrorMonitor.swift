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

public actor DriveSDKIntegrityErrorMonitor {
    private let environment: ObservabilityEnvProtocol.Type
    private let dateResource: DateResource
    private var reportedDecryptionErrorID: Set<String> = []
    private var reportedVerificationErrorID: Set<String> = []
    private var lastReportedDate: Date?

    public init(
        environment: ObservabilityEnvProtocol.Type = ObservabilityEnv.self,
        dateResource: DateResource = PlatformCurrentDateResource()
    ) {
        self.environment = environment
        self.dateResource = dateResource
    }

    public func reportDecryptionError(uid: String, label: DriveSDKIntegrityDecryptionErrorLabel) {
        // not report the same entity more than once
        if reportedDecryptionErrorID.contains(uid) { return }
        reportedDecryptionErrorID.insert(uid)
        let event = ObservabilityEvent(
            name: DriveSDKIntegrityObservabilityName.decryptionErrorsTotal.rawValue,
            labels: label,
            version: .v1
        )
        environment.report(event)
    }

    public func reportBlockVerificationError(retryHelped: String) {
        let event = ObservabilityEvent(
            name: DriveSDKIntegrityObservabilityName.blockVerificationErrorsTotal.rawValue,
            labels: [DriveSDKObservabilityLabelKey.retryHelped.rawValue: retryHelped],
            version: .v1
        )
        environment.report(event)
    }

    public func reportVerificationError(uid: String, label: DriveSDKIntegrityVerificationErrorLabel) {
        if reportedVerificationErrorID.contains(uid) { return }
        reportedVerificationErrorID.insert(uid)
        let event = ObservabilityEvent(
            name: DriveSDKIntegrityObservabilityName.verificationErrorsTotal.rawValue,
            labels: label,
            version: .v1
        )
        environment.report(event)
    }

    public func reportErroringUser(volumeType: String, userPlan: String) {
        let current = dateResource.getDate()
        guard isAllowedToReportErroringUser(current: current) else { return }
        lastReportedDate = current
        let event = ObservabilityEvent(
            name: DriveSDKIntegrityObservabilityName.erroringUsersTotal.rawValue,
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

enum DriveSDKIntegrityObservabilityName: String {
    case erroringUsersTotal = "drive_sdk_integrity_erroring_users_total"
    case verificationErrorsTotal = "drive_sdk_integrity_verification_errors_total"
    case blockVerificationErrorsTotal = "drive_sdk_integrity_block_verification_errors_total"
    case decryptionErrorsTotal = "drive_sdk_integrity_decryption_errors_total"
}
