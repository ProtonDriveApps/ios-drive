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
    case photosEnabled
    case photosUploadDisabled
    case photosBackgroundSyncEnabled
    case logsCompressionDisabled
    case domainReconnectionEnabled
    case postMigrationJunkFilesCleanup
    case newTrayAppMenuEnabled
    case pushNotificationIsEnabled
    case logCollectionEnabled
    case logCollectionDisabled
    case oneDollarPlanUpsellEnabled

    // Sharing
    case driveSharingMigration
    case driveSharingDevelopment
    case driveSharingInvitations
    case driveSharingExternalInvitations
    case driveSharingDisabled
    case driveSharingExternalInvitationsDisabled
    case driveSharingEditingDisabled
}
