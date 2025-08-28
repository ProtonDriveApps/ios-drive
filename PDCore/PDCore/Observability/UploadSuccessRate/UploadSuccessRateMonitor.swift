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
import ProtonCoreObservability

final class UploadSuccessRateMonitor {
    private let environment: ObservabilityEnvProtocol.Type
    private let queue = DispatchQueue(label: "me.proton.drive.UploadSuccessRateMonitor", qos: .utility)
    private var statusByItemId: [AnyVolumeIdentifier: AttemptType] = [:]

    init(environment: ObservabilityEnvProtocol.Type = ObservabilityEnv.self) {
        self.environment = environment
    }

    func incrementSuccess(
        identifier: any VolumeIdentifiable,
        shareType: DriveObservabilityUploadShareType,
        initiator: DriveObservabilityInitiator
    ) {
        let isRetry = isSuccessRetry(identifier: identifier)
        reportUpload(isSuccess: true, isRetry: isRetry, shareType: shareType, initiator: initiator)
    }
    
    func incrementFailure(
        identifier: any VolumeIdentifiable,
        shareType: DriveObservabilityUploadShareType,
        initiator: DriveObservabilityInitiator
    ) {
        let isRetry = isFailureRetry(identifier: identifier)
        reportUpload(isSuccess: false, isRetry: isRetry, shareType: shareType, initiator: initiator)
    }
    
    private func isSuccessRetry(identifier: any VolumeIdentifiable) -> Bool {
        queue.sync {
            statusByItemId.removeValue(forKey: identifier.any()) == nil ? false : true
        }
    }
    
    private func isFailureRetry(identifier: any VolumeIdentifiable) -> Bool {
        queue.sync {
            let identifier = identifier.any()
            if let itemStatus = statusByItemId[identifier] {
                if itemStatus == .firstAttempt {
                    statusByItemId[identifier] = .retry
                }
                return true
            }
            
            statusByItemId[identifier] = .firstAttempt
            return false
        }
    }
    
    private func reportUpload(
        isSuccess: Bool,
        isRetry: Bool,
        shareType: DriveObservabilityUploadShareType,
        initiator: DriveObservabilityInitiator
    ) {
        environment.report(
            .uploadSuccessRateEvent(
                status: isSuccess == true ? .success : .failure,
                retry: isRetry == true ? .true : .false,
                shareType: shareType,
                initiator: initiator
            )
        )
    }
}
