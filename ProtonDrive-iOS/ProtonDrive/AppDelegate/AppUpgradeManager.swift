// Copyright (c) 2026 Proton AG
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
import PDCore
import PDClient

final class AppUpgradeManager {
    private let localSettings: LocalSettings

    init(localSettings: LocalSettings) {
        self.localSettings = localSettings
    }

    func performUpgradeIfNeeded(appVersion: Version) {
        defer { localSettings.previousAppVersion = appVersion }
        guard
            let previousAppVersion = localSettings.previousAppVersion,
            appVersion > previousAppVersion
        else { return }
        // Reset flag until it's triggered again
        localSettings.upgradeRequirementResult = nil
        localSettings.hasDismissedUpgradeBanner = false
    }
}
