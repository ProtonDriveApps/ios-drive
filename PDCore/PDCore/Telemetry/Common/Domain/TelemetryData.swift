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

public struct TelemetryData: Equatable {
    public enum Group: Equatable {
        case photos
    }

    public enum Event: Equatable {
        case backupStopped
        case settingEnabled
        case settingDisabled
        case backupUpdate
        case backupBackgroundStart
        case backupBackgroundUpdate
        case uploadDone
        case upsellPhotos
    }

    let group: Group
    let event: Event
    let values: [String: Double]
    let dimensions: [String: String]

    public init(group: Group, event: Event, values: [String: Double] = [:], dimensions: [String: String] = [:]) {
        self.group = group
        self.event = event
        self.values = values
        self.dimensions = dimensions
    }
}
