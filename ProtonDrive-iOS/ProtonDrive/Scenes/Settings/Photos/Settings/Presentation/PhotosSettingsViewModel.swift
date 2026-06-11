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

import Combine
import Foundation
import PDCore
import PDLocalization
import PDPhotos
import PDClient
import PDCoreIOS
import ProtonCoreFeatureFlags

protocol PhotosSettingsViewModelProtocol: ObservableObject {
    var backupTitle: String { get }
    var mobileDataTitle: String { get }

    var shouldShowPhotoFeatureOption: Bool { get }
    var photoFeatureTitle: String { get }
    var photoFeatureAccessibilityID: String { get }
    var photoFeatureAlertMessage: String { get }
    var photoFeatureAlertButtonTitle: String { get }
    var photoFeatureAlertCancelTitle: String { get }
    var photoFeatureExplanation: String { get }
    var isPhotoFeatureDisabled: Bool { get }
    var isEnabled: Bool { get }
    var isMobileDataEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool)
    func setMobileDataEnabled(_ isEnabled: Bool)

    var isPhotoFeatureToggleInProgress: Bool { get }
    func togglePhotoFeatureEnableStatus() async
}

final class PhotosSettingsViewModel: PhotosSettingsViewModelProtocol {
    @Published var isPhotoFeatureDisabled: Bool
    @Published var isEnabled = false
    @Published var isMobileDataEnabled = false
    @Published var isPhotoFeatureToggleInProgress = false
    private var isBackupEnabled = false

    private let b2bSettingsUpdateDataSource: UpdateB2BUserSettingsDataSource
    private let settingsController: PhotoBackupSettingsController
    private let startController: PhotosBackupStartController
    private let localSettings: LocalSettings
    private let errorHandler: UserMessageHandlerProtocol
    private var cancellables = Set<AnyCancellable>()
    private let repository = ProtonCoreFeatureFlags.FeatureFlagsRepository.shared
    private let featureFlag = ProtonCoreDriveFeatureFlag.driveB2BPhotosUpload

    let backupTitle = Localization.setting_photo_backup
    let mobileDataTitle = Localization.setting_use_cellular_to_backup
    let photoFeatureAlertCancelTitle = Localization.general_cancel
    let photoFeatureExplanation = Localization.photo_feature_explanation

    init(
        settingsController: PhotoBackupSettingsController,
        startController: PhotosBackupStartController,
        localSettings: LocalSettings,
        b2bSettingsUpdateDataSource: UpdateB2BUserSettingsDataSource,
        errorHandler: UserMessageHandlerProtocol = UserMessageHandler()
    ) {
        self.settingsController = settingsController
        self.startController = startController
        self.localSettings = localSettings
        self.b2bSettingsUpdateDataSource = b2bSettingsUpdateDataSource
        self.errorHandler = errorHandler

        let isUnleashFlagEnabled = repository.isEnabled(featureFlag, reloadValue: true)
        let isUserEnablesPhoto = isUnleashFlagEnabled && localSettings.driveSettingsB2BPhotosEnabled
        let isPhotosEnabled = !localSettings.isB2BUser || !isUnleashFlagEnabled || isUserEnablesPhoto
        self.isPhotoFeatureDisabled = !isPhotosEnabled

        subscribeToUpdates()
    }

    var shouldShowPhotoFeatureOption: Bool {
        localSettings.isB2BUser && repository.isEnabled(featureFlag, reloadValue: true)
    }

    var photoFeatureTitle: String {
        if isPhotoFeatureDisabled {
            return Localization.photo_feature_enable_title
        } else {
            return Localization.photo_feature_disable_title
        }
    }
    var photoFeatureAccessibilityID: String {
        if isPhotoFeatureDisabled {
            return "PhotosBackupSettings.PhotoFeature.disabled"
        } else {
            return "PhotosBackupSettings.PhotoFeature.enabled"
        }
    }
    var photoFeatureAlertMessage: String {
        if isPhotoFeatureDisabled {
            return Localization.photo_feature_enable_alert_message
        } else {
            return Localization.photo_feature_disable_alert_message
        }
    }
    var photoFeatureAlertButtonTitle: String {
        if isPhotoFeatureDisabled {
            return Localization.general_enable
        } else {
            return Localization.general_disable
        }
    }

    private func subscribeToUpdates() {
        settingsController.isEnabled
            .sink { [weak self] value in
                self?.isBackupEnabled = value
                self?.isEnabled = value
            }
            .store(in: &cancellables)
        settingsController.isNetworkConstrained
            .map { !$0 }
            .assign(to: &$isMobileDataEnabled)
    }

    func setEnabled(_ isEnabled: Bool) {
        if isEnabled {
            Log.info("User enables photo backup", domain: .application)
        } else {
            Log.info("User disable photo backup", domain: .application)
        }
        if isEnabled {
            startController.start()
        } else {
            settingsController.setEnabled(isEnabled)
        }
    }

    func setMobileDataEnabled(_ isEnabled: Bool) {
        let isConstrained = !isEnabled
        settingsController.setNetworkConnectionConstrained(isConstrained)
    }

    func togglePhotoFeatureEnableStatus() async {
        guard !isPhotoFeatureToggleInProgress else { return }

        await MainActor.run {
            isPhotoFeatureToggleInProgress = true
        }

        defer {
            Task { @MainActor in
                isPhotoFeatureToggleInProgress = false
            }
        }

        do {
            let nextStatus = !localSettings.driveSettingsB2BPhotosEnabled
            try await b2bSettingsUpdateDataSource.updateB2BUserSettings(to: nextStatus)

            await MainActor.run {
                localSettings.driveSettingsB2BPhotosEnabled = nextStatus
                setEnabled(nextStatus)
                isPhotoFeatureDisabled = !nextStatus
            }

        } catch {
            Log.error(error: error, domain: .userSettings)

            await MainActor.run {
                errorHandler.handleError(PlainMessageError(error.localizedDescription))
            }
        }
    }

}
