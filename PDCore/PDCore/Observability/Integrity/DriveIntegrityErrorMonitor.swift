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
import ProtonCoreUtilities
import ProtonCoreObservability

public class DriveIntegrityErrorMonitor {

    @SettingsStorage("DriveIntegrityErrorMonitor.latestUserReportDate") private static var latestUserReportDate: Date?

    private static var planType = DriveObservabilityIntegrityPlan.unknown

    // Specification dictates that decryption errors should only be sent
    // once per item, per application run.
    private static var reportedIDs: Atomic<Set<String>> = .init([])

    private init() {}

    private static func reportUserAffected(shareType: DriveObservabilityIntegrityShareType) {
        let previousDate = latestUserReportDate ?? Date(timeIntervalSince1970: 0)
        let currentDate = Date()
        let fiveMinutes: TimeInterval = 5 * 60
        let timeIntervalSinceLastUserReport = currentDate.timeIntervalSince(previousDate)

        // Only send a user report if the previous report was sent at least 5 minutes ago
        guard timeIntervalSinceLastUserReport > fiveMinutes else { return }

        latestUserReportDate = currentDate

        ObservabilityEnv.report(
            .erroringUserEvent(
                plan: planType,
                shareType: shareType
            )
        )
    }

    private static func wasPreviouslyReported(_ id: String) -> Bool {
        var previouslyReported = false
        reportedIDs.mutate {
            previouslyReported = $0.contains(id)
            $0.insert(id)
        }
        return previouslyReported
    }

    public static func configure(with suite: SettingsStorageSuite, forUserWithPlan hasPlan: Bool?) {
        reportedIDs.mutate({ $0.removeAll() })
        _latestUserReportDate.configure(with: suite)
        planType = DriveObservabilityIntegrityPlan.from(hasPlan)
    }

    // Must be called from within a managed object context
    public static func reportMetadataError(for node: Node) {
        if DriveObservabilityIntegrityBeforeFebruary2025.from(node) != .no {
            reportUserAffected(shareType: .from(node))
        }

        guard !wasPreviouslyReported(node.id) else { return }

        ObservabilityEnv.report(
            .decryptionErrorEvent(
                entity: .node,
                shareType: .from(node),
                fromBeforeFebruary2025: .from(node)
            )
        )
    }
    
    public static func reportMetadataErrorDuringFileUpload(identifier: String, creationDate: Date) {
        if DriveObservabilityIntegrityBeforeFebruary2025.from(creationDate) != .no {
            reportUserAffected(shareType: .main)
        }
        
        guard !wasPreviouslyReported(identifier) else { return }

        ObservabilityEnv.report(
            .decryptionErrorEvent(
                entity: .node,
                shareType: .main,
                fromBeforeFebruary2025: .from(creationDate)
            )
        )
    }

    // Must be called from within a managed object context
    public static func reportContentError(for node: Node) {
        if DriveObservabilityIntegrityBeforeFebruary2025.from(node) != .no {
            reportUserAffected(shareType: .from(node))
        }

        guard !wasPreviouslyReported(node.id) else { return }

        ObservabilityEnv.report(
            .decryptionErrorEvent(
                entity: .content,
                shareType: .from(node),
                fromBeforeFebruary2025: .from(node)
            )
        )
    }
    
    public static func reportContentErrorDuringFileUpload(identifier: String, creationDate: Date) {
        if DriveObservabilityIntegrityBeforeFebruary2025.from(creationDate) != .no {
            reportUserAffected(shareType: .main)
        }
        
        guard !wasPreviouslyReported(identifier) else { return }

        ObservabilityEnv.report(
            .decryptionErrorEvent(
                entity: .content,
                shareType: .main,
                fromBeforeFebruary2025: .from(creationDate)
            )
        )
    }
    
    public static func reportUploadBlockVerificationError(for share: Share, fileSize: Int64) {
        if DriveObservabilityIntegrityBeforeFebruary2025.from(share) != .no {
            reportUserAffected(shareType: .from(share))
        }

        guard !wasPreviouslyReported(share.id) else { return }
        
        ObservabilityEnv.report(
            .uploadBlockVerificationErrorEvent(
                shareType: .from(share),
                retryHelped: .no,
                fileSize: .from(fileSize))
        )
    }

    // Must be called from within a managed object context
    public static func reportError(for share: Share) {
        if DriveObservabilityIntegrityBeforeFebruary2025.from(share) != .no {
            reportUserAffected(shareType: .from(share))
        }

        guard !wasPreviouslyReported(share.id) else { return }

        ObservabilityEnv.report(
            .decryptionErrorEvent(
                entity: .share,
                shareType: .from(share),
                fromBeforeFebruary2025: .from(share)
            )
        )
    }
}

private struct DriveObservabilityIntegrityDecryptionErrorEventLabels: Encodable, Equatable {
    let entity: DriveObservabilityIntegrityEntity
    let shareType: DriveObservabilityIntegrityShareType
    let fromBefore2024: DriveObservabilityIntegrityBeforeFebruary2025
}

private extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveObservabilityIntegrityDecryptionErrorEventLabels> {

    static func decryptionErrorEvent(
        entity: DriveObservabilityIntegrityEntity,
        shareType: DriveObservabilityIntegrityShareType,
        fromBeforeFebruary2025: DriveObservabilityIntegrityBeforeFebruary2025
    ) -> Self {
        .init(name: "drive_integrity_decryption_errors_total",
              labels: .init(entity: entity,
                            shareType: shareType,
                            fromBefore2024: fromBeforeFebruary2025),
              version: .v1)
    }
}

private struct DriveObservabilityIntegrityUploadBlockVerificationErrorEventLabels: Encodable, Equatable {
    let shareType: DriveObservabilityIntegrityShareType
    let retryHelped: DriveObservabilityIntegrityRetryHelped
    let fileSize: DriveObservabilityIntegrityFileSize
}

private extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveObservabilityIntegrityUploadBlockVerificationErrorEventLabels> {

    static func uploadBlockVerificationErrorEvent(
        shareType: DriveObservabilityIntegrityShareType,
        retryHelped: DriveObservabilityIntegrityRetryHelped,
        fileSize: DriveObservabilityIntegrityFileSize
    ) -> Self {
        .init(name: "drive_integrity_block_verification_errors_total",
              labels: .init(shareType: shareType,
                            retryHelped: retryHelped,
                            fileSize: fileSize),
              version: .v1)
    }
}

private struct DriveObservabilityIntegrityErroringUserEventLabels: Encodable, Equatable {
    let plan: DriveObservabilityIntegrityPlan
    let shareType: DriveObservabilityIntegrityShareType
}

private extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveObservabilityIntegrityErroringUserEventLabels> {

    static func erroringUserEvent(
        plan: DriveObservabilityIntegrityPlan,
        shareType: DriveObservabilityIntegrityShareType
    ) -> Self {
        .init(name: "drive_integrity_erroring_users_total",
              labels: .init(plan: plan,
                            shareType: shareType),
              version: .v1)
    }
}
