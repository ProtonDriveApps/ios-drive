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

import Foundation
import PDClient

/// Persists externally fetched feature flag values in UserDefaults.
///
/// ### Adding a new feature flag
/// 1. Add a case to `ExternalFeatureFlag` in PDClient with the Unleash flag name as `rawValue`.
/// 2. Declare a `@PersistedFeatureFlag` property below. Omit `key` when the UserDefaults key matches `rawValue`;
///    pass `key` only for legacy flags whose stored key differs from the Unleash name.
/// 3. If the flag should be cleared on sign-out or cache reset, add it to the appropriate list in `flagsCleanUpCatalog`.
/// 4. If the flag carries a variant payload, extend `ExternalFeatureFlag.hasPayload` in PDClient.
/// 5. Optional: add a composed property on `FeatureFlagsController` when the app needs rollout/killswitch logic.
public final class FeatureFlagCatalog {
    @PersistedFeatureFlag(.photosUploadDisabled, key: "photosUploadDisabled")
    var photosUploadDisabled: Bool
    @PersistedFeatureFlag(.logsCompressionDisabled, key: "logsCompressionDisabledValue")
    var logsCompressionDisabled: Bool
    @PersistedFeatureFlag(.domainReconnectionEnabled, key: "domainReconnectionEnabledValue")
    var domainReconnectionEnabled: Bool
    @PersistedFeatureFlag(.postMigrationJunkFilesCleanup, key: "postMigrationJunkFilesCleanupValue")
    var postMigrationJunkFilesCleanup: Bool
    @PersistedFeatureFlag(.oneDollarPlanUpsellEnabled, key: "oneDollarPlanUpsellEnabledValue")
    var oneDollarPlanUpsellEnabled: Bool
    @PersistedFeatureFlag(.pushNotificationIsEnabled, key: "pushNotificationIsEnabled")
    var pushNotificationIsEnabled: Bool
    @PersistedFeatureFlag(.driveMacFullResyncAlwaysVisibleDisabled)
    var driveMacFullResyncAlwaysVisibleDisabled: Bool
    @PersistedFeatureFlag(.driveMacPromoBannerDisabled)
    var driveMacPromoBannerDisabled: Bool
    @PersistedFeatureFlag(.driveMacGradualRolloutChannelEnabled)
    var driveMacGradualRolloutChannelEnabled: Bool
    @PersistedFeatureFlag(.driveMacAbnormalExitRelaunchDisabled)
    var driveMacAbnormalExitRelaunchDisabled: Bool
    @PersistedFeatureFlag(.driveCopyDisabled)
    var driveCopyDisabled: Bool
    @PersistedFeatureFlag(.drivePhotosTagsMigrationDisabled)
    var drivePhotosTagsMigrationDisabled: Bool

    // Sharing
    @PersistedFeatureFlag(.driveSharingMigration)
    var driveSharingMigration: Bool
    @PersistedFeatureFlag(.driveSharingExternalInvitations)
    var driveSharingExternalInvitations: Bool
    @PersistedFeatureFlag(.driveSharingDisabled)
    var driveSharingDisabled: Bool
    @PersistedFeatureFlag(.driveSharingExternalInvitationsDisabled)
    var driveSharingExternalInvitationsDisabled: Bool
    @PersistedFeatureFlag(.drivePublicShareEditMode)
    var drivePublicShareEditMode: Bool
    @PersistedFeatureFlag(.drivePublicShareEditModeDisabled)
    var drivePublicShareEditModeDisabled: Bool
    @PersistedFeatureFlag(.driveShareURLBookmarking)
    var driveShareURLBookmarking: Bool
    @PersistedFeatureFlag(.driveShareURLBookmarksDisabled)
    var driveShareURLBookmarksDisabled: Bool
    @PersistedFeatureFlag(.driveSharingAdminPermissions)
    var driveSharingAdminPermissions: Bool

    @PersistedFeatureFlag(.driveDisablePhotosForB2B)
    var driveDisablePhotosForB2B: Bool

    // Entitlement
    @PersistedFeatureFlag(.driveDynamicEntitlementConfiguration)
    var driveDynamicEntitlementConfiguration: Bool

    // Rating booster
    @PersistedFeatureFlag(.ratingIOSDrive)
    var ratingIOSDrive: Bool
    @PersistedFeatureFlag(.driveRatingBooster)
    var driveRatingBooster: Bool

    // Sheets
    @PersistedFeatureFlag(.docsSheetsEnabled, key: "DocsSheetsEnabledValue")
    var docsSheetsEnabled: Bool
    @PersistedFeatureFlag(.docsSheetsDisabled, key: "DocsSheetsDisabledValue")
    var docsSheetsDisabled: Bool
    @PersistedFeatureFlag(.docsCreateNewSheetOnMobileEnabled, key: "DocsCreateNewSheetOnMobileEnabledValue")
    var docsCreateNewSheetOnMobileEnabled: Bool

    @PersistedFeatureFlag(.driveiOSDebugMode)
    var driveiOSDebugMode: Bool
    @PersistedFeatureFlag(.driveiOSPaymentsV2)
    var driveiOSPaymentsV2: Bool
    @PersistedFeatureFlag(.driveMobileUpsellPlan)
    var driveMobileUpsellPlan: Bool

    // SDK
    @PersistedFeatureFlag(.driveiOSSDKNodeOperations, key: "DriveiOSSDKNodeOperationsValue")
    var driveiOSSDKNodeOperations: Bool
    @PersistedFeatureFlag(.driveCryptoEncryptBlocksWithPgpAead, key: "DriveCryptoEncryptBlocksWithPgpAeadValue")
    var driveCryptoEncryptBlocksWithPgpAead: Bool
    @PersistedFeatureFlag(.driveMacFileProviderBatchingDisabled)
    var driveMacFileProviderBatchingDisabled: Bool
    @PersistedFeatureFlag(.driveSyncMetadataScanV2Enabled)
    var driveSyncMetadataScanV2Enabled: Bool
    @PersistedFeatureFlag(.driveMacDecryptPassphraseIterativeDisabled)
    var driveMacDecryptPassphraseIterativeDisabled: Bool
    @PersistedFeatureFlag(.driveDownloadVerificationDisabled)
    var driveDownloadVerificationDisabled: Bool
    @PersistedFeatureFlag(.driveUploadVerificationDisabled)
    var driveUploadVerificationDisabled: Bool
    @PersistedFeatureFlag(.driveiOSSDKCreateFolder)
    var driveiOSSDKCreateFolder: Bool
    @PersistedFeatureFlag(.driveiOSSDKTrashNode)
    var driveiOSSDKTrashNode: Bool
    @PersistedFeatureFlag(.driveiOSSDKTrashOperations)
    var driveiOSSDKTrashOperations: Bool
    @PersistedFeatureFlag(.driveiOSSDKDevicesOperations)
    var driveiOSSDKDevicesOperations: Bool
    @PersistedFeatureFlag(.driveClientTestsEnabled)
    var driveClientTestsEnabled: Bool
    @PersistedFeatureFlag(.driveiOSUnlimitedPickerSelection)
    var driveiOSUnlimitedPickerSelection: Bool
    @PersistedFeatureFlag(.driveiOSDownloadMultiple)
    var driveiOSDownloadMultiple: Bool
    @PersistedFeatureFlag(.driveiOSPhotosGridZoom)
    var driveiOSPhotosGridZoom: Bool

    private var lookupTable: LookupTable!

    public init() {}

    func configure(with suite: SettingsStorageSuite) {
        storages.forEach { $0.configure(with: suite) }
        lookupTable = LookupTable(storages: storages)
    }

    func isEnabled(_ flag: ExternalFeatureFlag) -> Bool {
        lookupTable.isEnabled(flag)
    }

    func setValue(_ flag: ExternalFeatureFlag, value: Bool, payload: String?) {
        lookupTable.setValue(flag, value: value, payload: payload)
    }

    func clear(_ flags: [ExternalFeatureFlag]) {
        lookupTable.clear(flags)
    }

    func cleanUp(cleanUserSpecificSettings: Bool) {
        let (generalFlags, userSpecificFlags) = flagsCleanUpCatalog()
        clear(generalFlags)
        if cleanUserSpecificSettings {
            clear(userSpecificFlags)
        }
    }
}

extension FeatureFlagCatalog {
    var driveMobileUpsellPlanPayload: String? {
        get { _driveMobileUpsellPlan.payload }
        set { _driveMobileUpsellPlan.payload = newValue }
    }

    var storages: [PersistedFeatureFlag] {
        let mirror = Mirror(reflecting: self)
        var storages: [PersistedFeatureFlag] = []
        for child in mirror.children {
            guard let flag = child.value as? PersistedFeatureFlag else { continue }
            storages.append(flag)
        }
        return storages
    }

    func flagsCleanUpCatalog() -> (generalFlags: [ExternalFeatureFlag], userSpecificFlags: [ExternalFeatureFlag]) {
        let generalFlags: [ExternalFeatureFlag] = [
            .photosUploadDisabled,
            .logsCompressionDisabled,
            .domainReconnectionEnabled,
            .postMigrationJunkFilesCleanup,
            .driveMacFullResyncAlwaysVisibleDisabled,
            .driveMacAbnormalExitRelaunchDisabled,
            .pushNotificationIsEnabled,
            .driveDisablePhotosForB2B,
            .driveSharingMigration,
            .driveSharingExternalInvitations,
            .driveSharingDisabled,
            .driveSharingExternalInvitationsDisabled,
            .driveSharingAdminPermissions,
            .drivePublicShareEditMode,
            .driveShareURLBookmarking,
            .driveShareURLBookmarksDisabled,
            .drivePublicShareEditModeDisabled,
            .driveDynamicEntitlementConfiguration,
            .ratingIOSDrive,
            .driveRatingBooster,
            .driveiOSDebugMode,
            .driveCopyDisabled,
            .drivePhotosTagsMigrationDisabled,
            .driveMobileUpsellPlan,
            .oneDollarPlanUpsellEnabled,
            .driveMacPromoBannerDisabled,
            .driveMacGradualRolloutChannelEnabled,
            .docsSheetsEnabled,
            .docsSheetsDisabled,
            .docsCreateNewSheetOnMobileEnabled,
            .driveiOSPaymentsV2,
            .driveMacDecryptPassphraseIterativeDisabled
        ]
        let userSpecificFlags: [ExternalFeatureFlag] = [
            .driveiOSSDKNodeOperations,
            .driveMacFileProviderBatchingDisabled,
            .driveSyncMetadataScanV2Enabled,
            .driveCryptoEncryptBlocksWithPgpAead,
            .driveDownloadVerificationDisabled,
            .driveUploadVerificationDisabled,
            .driveiOSSDKCreateFolder,
            .driveiOSSDKTrashNode,
            .driveiOSSDKTrashOperations,
            .driveiOSSDKDevicesOperations,
            .driveClientTestsEnabled,
            .driveiOSUnlimitedPickerSelection,
            .driveiOSDownloadMultiple,
            .driveiOSPhotosGridZoom
        ]
        return (generalFlags, userSpecificFlags)
    }
}

private extension FeatureFlagCatalog {
    final class LookupTable {
        private let flags: [ExternalFeatureFlag: PersistedFeatureFlag]

        init(storages: [PersistedFeatureFlag]) {
            flags = Dictionary(uniqueKeysWithValues: storages.map { ($0.flag, $0) })
        }

        func isEnabled(_ flag: ExternalFeatureFlag) -> Bool {
            flags[flag]?.wrappedValue ?? false
        }

        func setValue(_ flag: ExternalFeatureFlag, value: Bool, payload: String?) {
            guard let storage = flags[flag] else { return }
            storage.wrappedValue = value
            if flag.hasPayload {
                storage.payload = payload
            }
        }

        func clear(_ flagsToClear: [ExternalFeatureFlag]) {
            flagsToClear.forEach { flags[$0]?.clearValue() }
        }
    }
}
