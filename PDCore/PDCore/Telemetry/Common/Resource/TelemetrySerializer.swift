// Copyright (c) 2023 Proton AG
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

import PDClient

protocol TelemetrySerializer {
    func serialize(data: TelemetryData) -> TelemetryEventInfo
}

final class DriveTelemetrySerializer: TelemetrySerializer {
    func serialize(data: TelemetryData) -> TelemetryEventInfo {
        TelemetryEventInfo(
            measurementGroup: serializeGroup(group: data.group),
            event: serialize(event: data.event),
            values: data.values,
            dimensions: data.dimensions
        )
    }

    private func serializeGroup(group: TelemetryData.Group) -> String {
        switch group {
        case .photos:
            return "drive.any.photos"
        }
    }

    private func serialize(event: TelemetryData.Event) -> String {
        switch event {
        case .backupStopped:
            return "backup.stopped"
        case .settingEnabled:
            return "setting.enabled"
        case .settingDisabled:
            return "setting.disabled"
        case .backupUpdate:
            return "backup.update"
        case .backupBackgroundStart:
            return "backup.background.start"
        case .backupBackgroundUpdate:
            return "backup.background.update"
        case .uploadDone:
            return "upload.done"
        case .upsellPhotos:
            return "upsell_photos"
        }
    }
}
