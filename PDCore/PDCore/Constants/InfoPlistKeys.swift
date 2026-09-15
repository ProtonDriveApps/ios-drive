// Copyright (c) 2026 Proton AG
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

/// Key for info.plist 
public enum InfoPlistKeys: String {
    case host = "DEFAULT_API_HOST"

    case appStorePageURL = "APPSTORE_PAGE_LINK"
    case appVersionIdentifier = "APP_VERSION_IDENTIFIER"
    case photosReminderDelay = "DEFAULT_PHOTOS_REMINDER_DELAY"
    case uploadedPhotoNotification = "UPLOADED_PHOTO_NOTIFICATION"
    case sdkVersion = "DRIVE_SDK_VERSION"
    case shortVersion = "CFBundleShortVersionString"
    case bundleVersion = "CFBundleVersion"
    case displayName = "CFBundleDisplayName"
    case isUITest = "IS_UI_TEST"
    case dynamicDomain = "DYNAMIC_DOMAIN"
}

public struct BundleInfo {
    public static func value<V>(
        for key: InfoPlistKeys,
        in infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> V? {
        infoDictionary?[key.rawValue] as? V
    }
}
