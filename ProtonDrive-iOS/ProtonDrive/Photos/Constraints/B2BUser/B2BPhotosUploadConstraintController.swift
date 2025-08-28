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

import Combine
import PDCore
import PDCoreIOS
import PDPhotos
import Foundation
import ProtonCoreFeatureFlags

final class B2BPhotosUploadConstraintController: PhotoBackupConstraintController {
    private let isUploadConstrained: CurrentValueSubject<Bool, Never>
    private var cancellables = Set<AnyCancellable>()
    /// A publisher that emits `true` when the upload is not allowed, and `false` when it is allowed.
    private let featureFlag = ProtonCoreDriveFeatureFlag.driveB2BPhotosUpload

    init(localSettings: LocalSettings, repository: ProtonCoreFeatureFlags.FeatureFlagsRepository) {
        let initialFlagEnabled = repository.isEnabled(featureFlag, reloadValue: true)
        let initialState = B2BPhotosUploadConstraintController.evaluateConstrained(
            localSettings: localSettings,
            hasFeature: initialFlagEnabled,
            b2bPhotosEnabled: localSettings.driveSettingsB2BPhotosEnabled
        )
        let subject = CurrentValueSubject<Bool, Never>(initialState)
        self.isUploadConstrained = subject

        // Only for B2B users
        guard localSettings.isB2BUser else { return }

        // Observe UserDefaults changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .map { [repository, featureFlag] _ in
                repository.isEnabled(featureFlag, reloadValue: true)
            }
            .removeDuplicates()
            .combineLatest(localSettings.publisher(for: \.driveSettingsB2BPhotosEnabled))
            .sink { [subject, localSettings] ffEnabled, settingEnabled in
                let isConstrained = B2BPhotosUploadConstraintController.evaluateConstrained(
                    localSettings: localSettings,
                    hasFeature: ffEnabled,
                    b2bPhotosEnabled: settingEnabled
                )
                subject.send(isConstrained)
            }
            .store(in: &cancellables)
    }

    var constraint: AnyPublisher<Bool, Never> {
        isUploadConstrained
            .removeDuplicates()
            .handleEvents(receiveOutput: {
                Log.info("B2BPhotosUploadConstraintController.isAllowedSubject 📸: \($0)", domain: .photosProcessing)
            })
            .eraseToAnyPublisher()
    }

    private static func evaluateConstrained(
        localSettings: LocalSettings,
        hasFeature: Bool,
        b2bPhotosEnabled: Bool
    ) -> Bool {
        // If not B2B, allow. We assume a B2B user cannot become a regular user, and vice versa.
        guard localSettings.isB2BUser else { return false }
        // If FF is off, allow
        guard hasFeature else { return false }
        // If B2B Photos are not enabled, then it is constrained
        return !b2bPhotosEnabled
    }
}
