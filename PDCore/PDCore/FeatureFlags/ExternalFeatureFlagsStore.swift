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

public protocol ExternalFeatureFlagsStore: AnyObject {
    func setFeatureEnabled(_ flag: FeatureAvailabilityFlag, value: Bool)
    func isFeatureEnabled(_ flag: FeatureAvailabilityFlag) -> Bool
}

extension LocalSettings: ExternalFeatureFlagsStore {
    // swiftlint:disable:next cyclomatic_complexity
    public func setFeatureEnabled(_ flag: FeatureAvailabilityFlag, value: Bool) {
        switch flag {
        case .photosUploadDisabled: photosUploadDisabled = value
        case .logsCompressionDisabled: logsCompressionDisabled = value
        case .domainReconnectionEnabled: domainReconnectionEnabled = value
        case .postMigrationJunkFilesCleanup: postMigrationJunkFilesCleanup = value
        case .pushNotificationIsEnabled: pushNotificationIsEnabled = value
        case .logCollectionEnabled: logCollectionEnabled = value
        case .logCollectionDisabled: logCollectionDisabled = value
        case .oneDollarPlanUpsellEnabled: oneDollarPlanUpsellEnabled = value
        case .driveDisablePhotosForB2B: driveDisablePhotosForB2B = value
        case .driveDDKEnabled: driveDDKEnabled = value
        case .driveMacSyncRecoveryDisabled: driveMacSyncRecoveryDisabled = value
        case .driveMacKeepDownloadedDisabled: driveMacKeepDownloadedDisabled = value
        // Sharing
        case .driveSharingMigration: driveSharingMigration = value
        case .driveSharingInvitations: driveSharingInvitations = value
        case .driveSharingExternalInvitations: driveSharingExternalInvitations = value
        case .driveSharingDisabled: driveSharingDisabled = value
        case .driveSharingExternalInvitationsDisabled: driveSharingExternalInvitationsDisabled = value
        case .driveSharingEditingDisabled: driveSharingEditingDisabled = value
        case .drivePublicShareEditMode: drivePublicShareEditMode = value
        case .drivePublicShareEditModeDisabled: drivePublicShareEditModeDisabled = value
        case .driveMobileSharingInvitationsAcceptReject: driveMobileSharingInvitationsAcceptReject = value
        case .driveShareURLBookmarking: driveShareURLBookmarking = value
        case .driveShareURLBookmarksDisabled: driveShareURLBookmarksDisabled = value
        // Album
        case .driveAlbumsDisabled: driveAlbumsDisabled = value
        case .driveCopyDisabled: driveCopyDisabled = value
        case .drivePhotosTagsMigration: drivePhotosTagsMigration = value
        case .drivePhotosTagsMigrationDisabled: drivePhotosTagsMigrationDisabled = value

        // ProtonDoc
        case .driveDocsDisabled: driveDocsDisabled = value
        // Rating booster
        // Legacy feature flags we used before migrating to Unleash
        case .ratingIOSDrive: ratingIOSDrive = value
        case .driveRatingBooster: driveRatingBooster = value
        // Entitlement
        case .driveDynamicEntitlementConfiguration: driveDynamicEntitlementConfiguration = value
        // Refactor
        case .driveiOSRefreshableBlockDownloadLink: driveiOSRefreshableBlockDownloadLink = value
        // Computers
        case .driveiOSComputers: driveiOSComputers = value
        case .driveiOSComputersDisabled: driveiOSComputersDisabled = value
        // Sheets
        case .docsSheetsEnabled: docsSheetsEnabled = value
        case .docsSheetsDisabled: docsSheetsDisabled = value
        case .docsCreateNewSheetOnMobileEnabled: docsCreateNewSheetOnMobileEnabled = value
        case .driveiOSDebugMode: driveiOSDebugMode = value
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func isFeatureEnabled(_ flag: FeatureAvailabilityFlag) -> Bool {
        switch flag {
        case .photosUploadDisabled: return photosUploadDisabled
        case .logsCompressionDisabled: return logsCompressionDisabled
        case .domainReconnectionEnabled: return domainReconnectionEnabled
        case .postMigrationJunkFilesCleanup: return postMigrationJunkFilesCleanup
        case .pushNotificationIsEnabled: return pushNotificationIsEnabled
        case .logCollectionEnabled: return logCollectionEnabled
        case .logCollectionDisabled: return logCollectionDisabled
        case .oneDollarPlanUpsellEnabled: return oneDollarPlanUpsellEnabled
        case .driveDisablePhotosForB2B: return driveDisablePhotosForB2B
        case .driveDDKEnabled: return driveDDKEnabled
        case .driveMacSyncRecoveryDisabled: return driveMacSyncRecoveryDisabled
        case .driveMacKeepDownloadedDisabled: return driveMacKeepDownloadedDisabled
        // Sharing
        case .driveSharingMigration: return driveSharingMigration
        case .driveSharingInvitations: return driveSharingInvitations
        case .driveSharingExternalInvitations: return driveSharingExternalInvitations
        case .driveSharingDisabled: return driveSharingDisabled
        case .driveSharingExternalInvitationsDisabled: return driveSharingExternalInvitationsDisabled
        case .driveSharingEditingDisabled: return driveSharingEditingDisabled
        case .drivePublicShareEditMode: return drivePublicShareEditMode
        case .drivePublicShareEditModeDisabled: return drivePublicShareEditModeDisabled
        case .driveMobileSharingInvitationsAcceptReject: return driveMobileSharingInvitationsAcceptReject
        case .driveShareURLBookmarking: return driveShareURLBookmarking
        case .driveShareURLBookmarksDisabled: return driveShareURLBookmarksDisabled
        // Album
        case .driveAlbumsDisabled: return driveAlbumsDisabled
        case .driveCopyDisabled: return driveCopyDisabled
        case .drivePhotosTagsMigration: return drivePhotosTagsMigration
        case .drivePhotosTagsMigrationDisabled: return drivePhotosTagsMigrationDisabled
        // ProtonDoc
        case .driveDocsDisabled: return driveDocsDisabled
        // Rating booster
        // Legacy feature flags we used before migrating to Unleash
        case .ratingIOSDrive: return ratingIOSDrive
        case .driveRatingBooster: return driveRatingBooster
        // Entitlement
        case .driveDynamicEntitlementConfiguration: return driveDynamicEntitlementConfiguration
        // Refactor
        case .driveiOSRefreshableBlockDownloadLink: return driveiOSRefreshableBlockDownloadLink
            // Computers
        case .driveiOSComputers: return driveiOSComputers
        case .driveiOSComputersDisabled: return driveiOSComputersDisabled
        // Sheets
        case .docsSheetsEnabled: return docsSheetsEnabled
        case .docsSheetsDisabled: return docsSheetsDisabled
        case .docsCreateNewSheetOnMobileEnabled: return docsCreateNewSheetOnMobileEnabled
        case .driveiOSDebugMode: return driveiOSDebugMode
        }
    }
}
