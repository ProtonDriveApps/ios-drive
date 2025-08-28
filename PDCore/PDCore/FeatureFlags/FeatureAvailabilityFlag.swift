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
import ProtonCoreFeatureFlags

public enum FeatureAvailabilityFlag: CaseIterable {
    case photosUploadDisabled
    case logsCompressionDisabled
    case domainReconnectionEnabled
    case postMigrationJunkFilesCleanup
    case pushNotificationIsEnabled
    case logCollectionEnabled
    case logCollectionDisabled
    case driveiOSDebugMode
    case oneDollarPlanUpsellEnabled
    case driveDisablePhotosForB2B
    case driveDDKEnabled
    case driveMacSyncRecoveryDisabled
    case driveMacKeepDownloadedDisabled

    // Sharing
    case driveSharingMigration
    case driveSharingInvitations
    case driveSharingExternalInvitations
    case driveSharingDisabled
    case driveSharingExternalInvitationsDisabled
    case driveSharingEditingDisabled
    case drivePublicShareEditMode
    case drivePublicShareEditModeDisabled
    case driveMobileSharingInvitationsAcceptReject
    case driveShareURLBookmarking
    case driveShareURLBookmarksDisabled

    // ProtonDoc
    case driveDocsDisabled
    
    // Rating booster
    // Legacy feature flags we used before migrating to Unleash
    case ratingIOSDrive
    case driveRatingBooster
    // Entitlement
    case driveDynamicEntitlementConfiguration

    // Refactor
    case driveiOSRefreshableBlockDownloadLink

    // Computers
    case driveiOSComputers
    case driveiOSComputersDisabled

    // Album
    case driveAlbumsDisabled
    case driveCopyDisabled
    case drivePhotosTagsMigration
    case drivePhotosTagsMigrationDisabled

    // Proton sheets
    case docsSheetsEnabled
    case docsSheetsDisabled
    case docsCreateNewSheetOnMobileEnabled
}
