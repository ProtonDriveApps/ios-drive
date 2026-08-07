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

public enum ExternalFeatureFlag: String, CaseIterable, Codable {
    case photosUploadDisabled = "DrivePhotosUploadDisabled"
    case logsCompressionDisabled = "DriveLogsCompressionDisabled"
    case domainReconnectionEnabled = "DriveDomainReconnectionEnabled"
    case postMigrationJunkFilesCleanup = "DrivePostMigrationJunkFilesCleanup"
    case pushNotificationIsEnabled = "PushNotifications"
    case driveiOSDebugMode = "DriveiOSDebugMode"
    case oneDollarPlanUpsellEnabled = "DriveOneDollarPlanUpsell"
    case driveDisablePhotosForB2B = "DriveDisablePhotosForB2B"
    case driveMacSyncRecoveryDisabled = "DriveMacSyncRecoveryDisabled"
    case driveMacPromoBannerDisabled = "DriveMacPromoBannerDisabled"
    case driveMacGradualRolloutChannelEnabled = "DriveMacGradualRolloutChannelEnabled"
    case driveMacAbnormalExitRelaunchDisabled = "DriveMacAbnormalExitRelaunchDisabled"

    // Sharing
    case driveSharingMigration = "DriveSharingMigration"
    case driveSharingExternalInvitations = "DriveSharingExternalInvitations"
    case driveSharingDisabled = "DriveSharingDisabled"
    case driveSharingExternalInvitationsDisabled = "DriveSharingExternalInvitationsDisabled"
    case driveSharingAdminPermissions = "DriveSharingAdminPermissions"
    case drivePublicShareEditMode = "DrivePublicShareEditMode"
    case drivePublicShareEditModeDisabled = "DrivePublicShareEditModeDisabled"
    case driveShareURLBookmarking = "DriveShareURLBookmarking"
    case driveShareURLBookmarksDisabled = "DriveShareURLBookmarksDisabled"

    // Rating booster
    // Legacy feature flags we used before migrating to Unleash
    case ratingIOSDrive = "RatingIOSDrive"
    case driveRatingBooster = "DriveRatingBooster"

    // Entitlement
    case driveDynamicEntitlementConfiguration = "DriveDynamicEntitlementConfiguration"

    // Albums
    case driveCopyDisabled = "DriveCopyDisabled"
    case drivePhotosTagsMigrationDisabled = "DrivePhotosTagsMigrationDisabled"

    // Sheets
    case docsSheetsEnabled = "DocsSheetsEnabled"
    case docsSheetsDisabled = "DocsSheetsDisabled"
    case docsCreateNewSheetOnMobileEnabled = "DocsCreateNewSheetOnMobileEnabled"

    // Payments
    case driveiOSPaymentsV2 = "DriveiOSPaymentsV2"

    // SDK
    case driveCryptoEncryptBlocksWithPgpAead = "DriveCryptoEncryptBlocksWithPgpAead"
    case driveMacFileProviderBatchingDisabled = "DriveMacFileProviderBatchingDisabled"
    case driveMacDecryptPassphraseIterativeDisabled = "DriveMacDecryptPassphraseIterativeDisabled"
    case driveiOSSDKNodeOperations = "DriveiOSSDKNodeOperations"
    case driveDownloadVerificationDisabled = "DriveDownloadVerificationDisabled"
    case driveUploadVerificationDisabled = "DriveUploadVerificationDisabled"
}
