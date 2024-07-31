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
            return "Your Mail storage is full"
        case .drive:
            return "Your Drive storage is full"
        case .storageFull:
            return "Your storage is full"
        case .orgIssueForPrimaryAdmin:
            return "Your subscription has ended"
        case .orgIssueForMember:
            return "Your account is at risk of deletion"
        case .hidden:
            return nil
        }
    }

    var bannerDescription: String? {
        switch self {
        case .mail:
            return "To send or receive emails, free up space or upgrade for more storage."
        case .drive, .storageFull:
            return "To upload files, free up space or upgrade for more storage."
        case .orgIssueForPrimaryAdmin:
            return "Upgrade to restore full access and to avoid data loss."
        case .orgIssueForMember:
            return "To avoid data loss, ask your admin to upgrade."
        case .hidden:
            return nil
        }
    }

    var bannerButtonTitle: String? {
        switch self {
        case .orgIssueForPrimaryAdmin:
            return "Upgrade"
        case .orgIssueForMember:
            return "Learn more"
        case .hidden:
            return nil
        default:
            return "Get more storage"
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
