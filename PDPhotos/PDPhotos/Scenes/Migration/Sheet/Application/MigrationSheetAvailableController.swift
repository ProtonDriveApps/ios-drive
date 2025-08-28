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

import PDCore
import PDCoreIOS

public protocol MigrationSheetAvailableControllerProtocol {
    func isAvailable() -> Bool
    func markShown()
}

final class MigrationSheetAvailableController: MigrationSheetAvailableControllerProtocol {
    private let localSettings: LocalSettings
    private let dateResource: DateResource

    init(localSettings: LocalSettings, dateResource: DateResource) {
        self.localSettings = localSettings
        self.dateResource = dateResource
    }

    func isAvailable() -> Bool {
        if let date = localSettings.photoVolumeMigrationLastShownDate {
            let currentDate = dateResource.getDate()
            let timeInterval = currentDate.timeIntervalSince(date)
            return timeInterval >= 7 * 24 * 60 * 60 // 1 week from last showing
        } else {
            return true
        }
    }

    func markShown() {
        let currentDate = dateResource.getDate()
        localSettings.photoVolumeMigrationLastShownDate = currentDate
    }
}

#if DEBUG
final class DisabledMigrationSheetAvailableController: MigrationSheetAvailableControllerProtocol {
    func isAvailable() -> Bool {
        return false
    }

    func markShown() {}
}
#endif
