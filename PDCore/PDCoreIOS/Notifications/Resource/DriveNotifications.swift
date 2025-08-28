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

public enum DriveNotification {
    case lock
    case checkAuthentication
    case signOut
    case toggleSideMenu
    case virtualBack
    case didDismissAlert
    case retryPhotoUpload
    case isLoggingOut
    case tabBar
    case banner

    public var name: Notification.Name {
        switch self {
        case .lock:
            return Notification.Name("DriveCoordinator.LockNotification")
        case .checkAuthentication:
            return Notification.Name("DriveNotification.checkAuthentication")
        case .signOut:
            return Notification.Name("DriveCoordinator.SignOutNotification")
        case .toggleSideMenu:
            return Notification.Name("DriveCoordinator.ToggleSideMenuNotification")
        case .virtualBack:
            return Notification.Name("DriveCoordinator.VirtualBack")
        case .didDismissAlert:
            return Notification.Name("DriveCoordinator.didDismissAlert")
        case .retryPhotoUpload:
            return Notification.Name("DriveNotification.retryPhotoUpload")
        case .isLoggingOut:
            return Notification.Name("DriveNotification.isLoggingOut")
        case .tabBar:
            return Notification.Name("FinderCoordinator.didEnterMultiSelection")
        case .banner:
            return Notification.Name("ProtonDrive.Banner")
        }
    }

    public var publisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: name, object: nil)
    }
}
