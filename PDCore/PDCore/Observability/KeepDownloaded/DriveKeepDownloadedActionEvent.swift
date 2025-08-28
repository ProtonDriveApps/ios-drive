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

// See mac_drive_keep_downloaded_actions_total_v1.schema.json

public struct DriveKeepDownloadedActionEventLabels: Encodable, Equatable {
    let action: DriveKeepDownloadedAction
    let type: DriveKeepDownloadedFileType
}

public extension ObservabilityEvent where Payload == PayloadWithValueAndLabels<Int, DriveKeepDownloadedActionEventLabels> {
    static func keepDownloadedActionEvent(action: DriveKeepDownloadedAction, type: DriveKeepDownloadedFileType) -> Self {
        .init(name: "mac_drive_keep_downloaded_actions_total", labels: .init(action: action, type: type))
    }
}
