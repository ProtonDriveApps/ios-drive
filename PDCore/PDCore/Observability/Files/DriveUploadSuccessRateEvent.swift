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

// See drive_upload_success_rate_total_v1.schema.json

// ShareType is a label that is found in other metrics, with similar but not identical properties,
// so it is defined separately for each to avoid sending an unsupported value.
public enum DriveObservabilityUploadShareType: String, Encodable, Equatable {
    case main
    case device
    case photo
    case shared
}

public struct DriveObservabilityUploadSuccessRateEventLabels: Encodable, Equatable {
    let status: DriveObservabilityStatus
    let retry: DriveObservabilityRetry
    let shareType: DriveObservabilityUploadShareType
    let initiator: DriveObservabilityInitiator
}

extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveObservabilityUploadSuccessRateEventLabels> {
    
    public static func uploadSuccessRateEvent(
        status: DriveObservabilityStatus,
        retry: DriveObservabilityRetry,
        shareType: DriveObservabilityUploadShareType,
        initiator: DriveObservabilityInitiator) -> Self {
            .init(name: "drive_upload_success_rate_total",
                  labels: .init(status: status,
                                retry: retry,
                                shareType: shareType,
                                initiator: initiator),
                  version: .v2)
        }
    
    public static func uploadSuccessRateEvent(
        status: DriveObservabilityStatus,
        retryCount: Int,
        fileDraft: FileDraft) -> Self {
            .uploadSuccessRateEvent(
                status: .failure,
                retry: .from(retryCount: retryCount),
                shareType: .from(fileDraft: fileDraft),
                initiator: .from(fileDraft: fileDraft))
        }
}
