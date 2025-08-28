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

import PDCoreIOS
import PDCore
import Foundation
import Combine

final class ApplicationUserSettingsController {
    private let localSettings: LocalSettings
    private let notificationCenter: NotificationCenter
    private var cancellables: Set<AnyCancellable> = []

    init(localSettings: LocalSettings, notificationCenter: NotificationCenter) {
        self.localSettings = localSettings
        self.notificationCenter = notificationCenter

        self.subscribeToChangesInB2BSettings()
    }

    private func subscribeToChangesInB2BSettings() {
        let initialValue = localSettings.driveSettingsB2BPhotosEnabled
        let isB2BUser = localSettings.isB2BUser

        localSettings
            .publisher(for: \.driveSettingsB2BPhotosEnabled)
            .filter { $0 != initialValue }
            .filter { _ in isB2BUser }
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled {
                    // Only reset tab if the current default is "photos"
                    if TabBarItem(rawValue: self.localSettings.defaultHomeTabTag) == .photos {
                        self.localSettings.defaultHomeTabTag = TabBarItem.files.rawValue
                    }

                    // We disable the backup for this device
                    self.localSettings.isPhotosBackupEnabled = false
                }
                self.notificationCenter.post(name: .restartApplication)
            }
            .store(in: &cancellables)
    }
}
