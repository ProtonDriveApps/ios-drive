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

/// drive_download_success_rate_total_v1

public enum DriveObservabilityShareType: String, Encodable, Equatable {
    case main
    case device
    case photo
    case shared
    /// The node is shared through public link
    case sharedPublic = "shared_public"
    case sharedPhoto = "shared_photo"

    static func from(node: Node) -> Self {
        guard let context = node.managedObjectContext else { return .shared }
        return context.performAndWait {
            // if the share is not there anyway, we need to
            // still decide about share type. Own shares are always loaded by
            // default, so we can bet that its not own/device/photo and thus
            // we can set its shared one.
            guard let contextShare = try? node.getContextShare() else { return .shared }
            switch contextShare.type {
            case .main: return .main
            case .photos: return .photo
            case .device: return .device
            default: break
            }
            return node.parentNode is CoreDataAlbum ? .sharedPhoto : .shared
        }
    }
}

public struct DriveObservabilityDownloadSuccessRateEventLabels: Encodable, Equatable {
    let status: DriveObservabilityStatus
    let retry: DriveObservabilityRetry
    let shareType: DriveObservabilityShareType
}

extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveObservabilityDownloadSuccessRateEventLabels> {
    public static func downloadSuccessRateEvent(
        status: DriveObservabilityStatus,
        retry: DriveObservabilityRetry,
        shareType: DriveObservabilityShareType
    ) -> Self {
        .init(
            name: "drive_download_success_rate_total",
            labels: .init(
                status: status,
                retry: retry,
                shareType: shareType
            ),
            version: .v1
        )
    }
}
