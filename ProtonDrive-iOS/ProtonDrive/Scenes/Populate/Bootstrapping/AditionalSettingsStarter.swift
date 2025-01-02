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
import PDCore

class AditionalSettingsStarter: AppBootstrapper {
    let generalSettings: GeneralSettings
    let settingsUpdater: TabbarSettingUpdaterProtocol
    let storage: StorageManager

    init(generalSettings: GeneralSettings, storage: StorageManager, settingsUpdater: TabbarSettingUpdaterProtocol) {
        self.generalSettings = generalSettings
        self.storage = storage
        self.settingsUpdater = settingsUpdater
    }

    func bootstrap() async throws {
        bootstrapGeneralSettings()
        try await bootstrapTabbarSettings()
    }

    /// opportunistic, no need to abort the boot if this call fails/
    private func bootstrapGeneralSettings() {
        generalSettings.fetchUserSettings()
    }

    private func bootstrapTabbarSettings() async throws {
        let context = storage.backgroundContext
        let mainShare = try await context.perform {
            // The original implementation used the photos share, but at the end the only thing needed is the volumeID.
            guard let mainShare = self.storage.getMainShares(in: context).first else {
                throw NukingCacheError("The main share existence is a compulsory requirement")
            }
            return mainShare
        }

        await settingsUpdater.updateTabSettingBasedOnUserPlan(share: mainShare)
    }
}
