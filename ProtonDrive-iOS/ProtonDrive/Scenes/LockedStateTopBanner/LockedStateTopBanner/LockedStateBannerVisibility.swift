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
import ProtonCoreDataModel
import PDLocalization

enum LockedStateAlertVisibility: Equatable {
    case mail
    case drive
    case storageFull
    case orgIssueForPrimaryAdmin
    case orgIssueForMember
    case hidden

    init(lockedFlags: LockedFlags) {
        self = .hidden

        if lockedFlags.contains(.orgIssueForPrimaryAdmin) {
            self = .orgIssueForPrimaryAdmin
        } else if lockedFlags.contains(.orgIssueForMember) {
            self = .orgIssueForMember
        } else if lockedFlags.contains(.storageExceeded) {
            self = .storageFull
        } else if lockedFlags.contains(.mailStorageExceeded) {
            self = .mail
        } else if lockedFlags.contains(.driveStorageExceeded) {
            self = .drive
        }
    }

    var bannerTitle: String? {
        switch self {
        case .mail:
            return Localization.state_mail_storage_full
        case .drive:
            return Localization.state_drive_storage_full
        case .storageFull:
            return Localization.state_storage_full
        case .orgIssueForPrimaryAdmin:
            return Localization.state_subscription_has_ended
        case .orgIssueForMember:
            return Localization.state_at_risk_of_deletion
        case .hidden:
            return nil
        }
    }

    var bannerDescription: String? {
        switch self {
        case .mail:
            return Localization.state_mail_storage_full_desc
        case .drive, .storageFull:
            return Localization.state_storage_full_desc
        case .orgIssueForPrimaryAdmin:
            return Localization.state_subscription_has_ended_desc
        case .orgIssueForMember:
            return Localization.state_at_risk_of_deletion_desc
        case .hidden:
            return nil
        }
    }

    var bannerButtonTitle: String? {
        switch self {
        case .orgIssueForPrimaryAdmin:
            return Localization.general_upgrade
        case .orgIssueForMember:
            return Localization.general_learn_more
        case .hidden:
            return nil
        default:
            return Localization.general_get_more_storage
        }
    }

    var bannerButtonUrl: String? {
        switch self {
        case .orgIssueForMember:
            return "https://proton.me/support/free-plan-limits"
        case .hidden:
            return nil
        default:
            return "https://account.proton.me/drive/dashboard"
        }
    }
}
