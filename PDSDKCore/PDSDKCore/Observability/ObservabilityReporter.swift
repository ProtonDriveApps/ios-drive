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
import ProtonDriveSDK
import PDCore

public enum FileVerificationData {
    case download(result: FileVerificationEvent.Result, fileSize: Int64, checksumVerified: Bool)
    case upload(sha1Provided: Bool)
}

public protocol ObservabilityReporterProtocol: AnyObject {
    func handle(event: MetricEvent)
    func reportFileVerification(_ data: FileVerificationData) async
}

public final class ObservabilityReporter: ObservabilityReporterProtocol {
    private let dependencies: Dependencies
    private var userPlan: String {
        guard let isPaid = dependencies.userInfoController.currentUser?.isPaid else { return "unknown" }
        return isPaid ? "paid" : "free"
    }

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func handle(event: MetricEvent) {
        Task {
            switch event {
            case .apiRetrySucceeded:
                dependencies.apiMonitor.reportApiRetrySucceeded()
            case .blockVerificationError(let payload):
                await dependencies.integrityErrorMonitor
                    .reportBlockVerificationError(retryHelped: payload.retryHelped.string)
            case .decryptionError(let payload):
                await reportDecryptionError(payload: payload)
            case .download(let payload):
                await reportDownloadEvent(payload: payload)
            case .upload(let payload):
                await reportUploadEvent(payload: payload)
            case .verificationError(let payload):
                await reportVerificationError(payload: payload)
            case .other(let name):
                handleOthers(name: name)
            }
        }
    }
    
    public func reportFileVerification(_ data: FileVerificationData) async {
        switch data {
        case let .download(result, fileSize, checksumVerified):
            await dependencies.fileVerificationMonitor.reportDownloadVerification(
                result: result,
                fileSize: fileSize,
                checksumVerified: checksumVerified
            )
        case .upload(let sha1Provided):
            await dependencies.fileVerificationMonitor.reportUploadVerification(sha1Provided: sha1Provided)
        }
    }

    private func reportDecryptionError(payload: DecryptionErrorEventPayload) async {
        let volumeType = payload.volumeType.stringValue
        let field = payload.field.stringValue
        await dependencies.integrityErrorMonitor.reportDecryptionError(
            uid: payload.uid,
            label: .init(
                volumeType: volumeType,
                field: field,
                fromBefore2024: payload.fromBefore2024.string
            )
        )
        if payload.fromBefore2024 == false {
            await dependencies.integrityErrorMonitor.reportErroringUser(volumeType: volumeType, userPlan: userPlan)

            Log.error("volumeType: \(volumeType), field: \(field), error: \(payload.error ?? "unknown")", domain: .sdk)
        }
    }

    private func reportVerificationError(payload: VerificationErrorEventPayload) async {
        let volumeType = payload.volumeType.stringValue
        await dependencies.integrityErrorMonitor.reportVerificationError(
            uid: payload.uid,
            label: .init(
                volumeType: volumeType,
                field: payload.field.stringValue,
                addressMatchingDefaultShare: payload.addressMatchingDefaultShare.string,
                fromBefore2024: payload.fromBefore2024.string
            )
        )
        if payload.fromBefore2024 == false && payload.addressMatchingDefaultShare {
            await dependencies.integrityErrorMonitor.reportErroringUser(volumeType: volumeType, userPlan: userPlan)
        }
    }

    private func reportUploadEvent(payload: UploadEventPayload) async {
        let volumeType = payload.volumeType.stringValue
        if let error = payload.error {
            await dependencies.uploadMonitor.reportExpectedSizeOnError(size: Int(payload.approximateExpectedSize))
            await dependencies.uploadMonitor.reportTransferSizeOnError(size: Int(payload.approximateUploadedSize))

            let isAborted = payload.originalError?.contains("A task was canceled") ?? false
            if isAborted { return }
            await dependencies.uploadMonitor.reportError(volumeType: volumeType, type: error.stringValue)

            // Exclusive network error
            if error == .networkError { return }
            await dependencies.uploadMonitor.reportSuccess(
                volumeType: volumeType,
                status: DriveObservabilityStatus.failure.rawValue
            )
            await dependencies.uploadMonitor.reportErroringUser(volumeType: volumeType, userPlan: userPlan)

            if error == .unknown, let message = payload.originalError {
                Log.error(message, domain: .sdk)
            }
        } else {
            await dependencies.uploadMonitor.reportSuccess(
                volumeType: volumeType,
                status: DriveObservabilityStatus.success.rawValue
            )
        }
    }

    private func reportDownloadEvent(payload: DownloadEventPayload) async {
        let volumeType = payload.volumeType.stringValue
        if let error = payload.error {
            await dependencies.downloadMonitor.reportClaimedFileSizeOnError(size: Int(payload.approximateClaimedFileSize))
            await dependencies.downloadMonitor.reportTransferSizeOnError(size: Int(payload.approximateDownloadedSize))

            let isAborted = payload.originalError?.contains("A task was canceled") ?? false
            if isAborted { return }
            await dependencies.downloadMonitor.reportError(volumeType: volumeType, type: error.stringValue)

            // Exclusive network error
            if error == .networkError { return }
            await dependencies.downloadMonitor.reportSuccess(
                volumeType: volumeType,
                status: DriveObservabilityStatus.failure.rawValue
            )
            await dependencies.downloadMonitor.reportErroringUser(volumeType: volumeType, userPlan: userPlan)

            if error == .unknown, let message = payload.originalError {
                Log.error(message, domain: .sdk)
            }
        } else {
            await dependencies.downloadMonitor.reportSuccess(
                volumeType: volumeType,
                status: DriveObservabilityStatus.success.rawValue
            )
        }
    }

    private func handleOthers(name: String) {
        if name == "debounceLongWait" {
            dependencies.apiMonitor.reportDebounce()
        }
    }
}

extension ObservabilityReporter {
    public struct Dependencies {
        let apiMonitor = DriveSDKAPIObservabilityMonitor()
        let integrityErrorMonitor = DriveSDKIntegrityErrorMonitor()
        let uploadMonitor = DriveSDKUploadObservabilityMonitor()
        let downloadMonitor = DriveSDKDownloadObservabilityMonitor()
        let fileVerificationMonitor = FileVerificationMonitor()
        let userInfoController: UserInfoController

        public init(userInfoController: UserInfoController) {
            self.userInfoController = userInfoController
        }
    }
}

extension VolumeType {
    var stringValue: String {
        switch self {
        case .ownVolume:
            return "own_volume"
        case .shared:
            return "shared"
        case .sharedPublic:
            return "shared_public"
        case .ownPhotoVolume:
            return "own_photo_volume"
        case .unknown:
            return "unknown"
        case .unrecognized:
            return "unrecognized"
        }
    }
}

extension EncryptedField {
    var stringValue: String {
        switch self {
        case .shareKey:
            return "shareKey"
        case .nodeKey:
            return "nodeKey"
        case .nodeName:
            return "nodeName"
        case .nodeHashKey:
            return "nodeHashKey"
        case .nodeExtendedAttributes:
            return "nodeExtendedAttributes"
        case .nodeContentKey:
            return "nodeContentKey"
        case .content:
            return "content"
        case .unknown:
            return "unknown"
        }
    }
}

extension UploadError {
    var stringValue: String {
        switch self {
        case.serverError:
            return "server_error"
        case .networkError:
            return "network_error"
        case .integrityError:
            return "integrity_error"
        case .rateLimited:
            return "rate_limited"
        case .httpClientSideError:
            return "4xx"
        case .unknown:
            return "unknown"
        }
    }
}

extension DownloadError {
    var stringValue: String {
        switch self {
        case.serverError:
            return "server_error"
        case .networkError:
            return "network_error"
        case .decryptionError:
            return "decryption_error"
        case .integrityError:
            return "integrity_error"
        case .rateLimited:
            return "rate_limited"
        case .httpClientSideError:
            return "4xx"
        case .unknown:
            return "unknown"
        }
    }
}

private extension Bool {
    var string: String {
        self ? "yes" : "no"
    }
}
