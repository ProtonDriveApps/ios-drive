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

public extension UserDefaults {
    enum FileProvider: String {
        case shouldReenumerateItemsKey = "shouldReenumerateItems"
        case workingSetEnumerationInProgressKey = "workingSetEnumerationInProgress"
        case fullResyncInProgressKey = "fullResyncInProgressKey"
        case cannotSynchronizeEarlyExitOccurredKey = "cannotSynchronizeEarlyExitOccurred"
        case cannotSynchronizeEarlyExitCountKey = "cannotSynchronizeEarlyExitCount"
        case fetchedItemCountKey = "fetchedItemCount"
        case resyncEnumerationPageCountKey = "resyncEnumerationPageCount"
        case pathsMarkedAsKeepDownloadedKey = "pathsMarkedAsKeepDownloaded"
        case pathsMarkedAsOnlineOnlyKey = "pathsMarkedAsOnlineOnly"
        case openItemsInBrowserKey = "openItemsInBrowser"
        case extensionPathKey = "fileProviderExtensionPath"
        case forceRemoveDomainOnSignOutKey = "forceRemoveDomainOnSignOut"
        case volumeLockCheckRequestedAtKey = "volumeLockCheckRequestedAt"
    }
    
    @objc dynamic var workingSetEnumerationInProgress: Bool {
        return bool(forKey: FileProvider.workingSetEnumerationInProgressKey.rawValue)
    }
    
    @objc dynamic var pathsMarkedAsKeepDownloaded: String? {
        return string(forKey: FileProvider.pathsMarkedAsKeepDownloadedKey.rawValue)
    }
    
    @objc dynamic var pathsMarkedAsOnlineOnly: String? {
        return string(forKey: FileProvider.pathsMarkedAsOnlineOnlyKey.rawValue)
    }
    
    @objc dynamic var openItemsInBrowser: String? {
        return string(forKey: FileProvider.openItemsInBrowserKey.rawValue)
    }

    @objc dynamic var fileProviderExtensionPath: String? {
        return string(forKey: FileProvider.extensionPathKey.rawValue)
    }

    /// Timestamp written by the File Provider extension at startup to ask the main app to validate whether
    /// the volume is locked on the BE (and clean up if so). The app is the authority for that check.
    @objc dynamic var volumeLockCheckRequestedAt: Double {
        return double(forKey: FileProvider.volumeLockCheckRequestedAtKey.rawValue)
    }
}
