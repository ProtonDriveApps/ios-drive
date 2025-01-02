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
        case .newTrayAppMenuEnabled: newTrayAppMenuEnabled = value
        case .pushNotificationIsEnabled: pushNotificationIsEnabled = value
        case .logCollectionEnabled: logCollectionEnabled = value
        case .logCollectionDisabled: logCollectionDisabled = value
        case .oneDollarPlanUpsellEnabled: oneDollarPlanUpsellEnabled = value
        case .driveDisablePhotosForB2B: driveDisablePhotosForB2B = value
        case .driveDDKEnabled: driveDDKEnabled = value
        // Sharing
        case .driveSharingMigration: driveSharingMigration = value
        case .driveiOSSharing: driveiOSSharing = value
        case .driveSharingDevelopment: driveSharingDevelopment = value
        case .driveSharingInvitations: driveSharingInvitations = value
        case .driveSharingExternalInvitations: driveSharingExternalInvitations = value
        case .driveSharingDisabled: driveSharingDisabled = value
        case .driveSharingExternalInvitationsDisabled: driveSharingExternalInvitationsDisabled = value
        case .driveSharingEditingDisabled: driveSharingEditingDisabled = value
        case .drivePublicShareEditMode: drivePublicShareEditMode = value
        case .drivePublicShareEditModeDisabled: drivePublicShareEditModeDisabled = value
        // ProtonDoc
        case .driveDocsWebView: driveDocsWebView = value
        case .driveDocsDisabled: driveDocsDisabled = value
        // Entitlement
        case .driveDynamicEntitlementConfiguration: driveDynamicEntitlementConfiguration = value
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func isFeatureEnabled(_ flag: FeatureAvailabilityFlag) -> Bool {
        switch flag {
        case .photosUploadDisabled: return photosUploadDisabled
        case .logsCompressionDisabled: return logsCompressionDisabled
        case .domainReconnectionEnabled: return domainReconnectionEnabled
        case .postMigrationJunkFilesCleanup: return postMigrationJunkFilesCleanup
        case .newTrayAppMenuEnabled: return newTrayAppMenuEnabled
        case .pushNotificationIsEnabled: return pushNotificationIsEnabled
        case .logCollectionEnabled: return logCollectionEnabled
        case .logCollectionDisabled: return logCollectionDisabled
        case .oneDollarPlanUpsellEnabled: return oneDollarPlanUpsellEnabled
        case .driveDisablePhotosForB2B: return driveDisablePhotosForB2B
        case .driveDDKEnabled: return driveDDKEnabled
        // Sharing
        case .driveSharingMigration: return driveSharingMigration
        case .driveiOSSharing: return driveiOSSharing
        case .driveSharingDevelopment: return driveSharingDevelopment
        case .driveSharingInvitations: return driveSharingInvitations
        case .driveSharingExternalInvitations: return driveSharingExternalInvitations
        case .driveSharingDisabled: return driveSharingDisabled
        case .driveSharingExternalInvitationsDisabled: return driveSharingExternalInvitationsDisabled
        case .driveSharingEditingDisabled: return driveSharingEditingDisabled
        case .drivePublicShareEditMode: return drivePublicShareEditMode
        case .drivePublicShareEditModeDisabled: return drivePublicShareEditModeDisabled
        // ProtonDoc
        case .driveDocsWebView: return driveDocsWebView
        case .driveDocsDisabled: return driveDocsDisabled
        // Entitlement
        case .driveDynamicEntitlementConfiguration: return driveDynamicEntitlementConfiguration
        }
    }
}
