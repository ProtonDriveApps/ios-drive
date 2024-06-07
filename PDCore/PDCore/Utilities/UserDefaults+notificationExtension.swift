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
    enum NotificationPropertyKeys: String {
        case metadataDBUpdateKey = "metadataDBUpdate"
        case syncErrorDBUpdateKey = "syncErrorDBUpdate"
        case syncingKey = "syncing"
        case childSessionReadyKey = "childSessionReady"
        case childSessionExpiredKey = "childSessionExpired"
        case cryptoServerTime = "cryptoServerTime"
    }

    // Keys and properties MUST MATCH one another
    @objc dynamic var metadataDBUpdate: TimeInterval {
        return double(forKey: NotificationPropertyKeys.metadataDBUpdateKey.rawValue)
    }

    @objc dynamic var syncErrorDBUpdate: TimeInterval {
        return double(forKey: NotificationPropertyKeys.syncErrorDBUpdateKey.rawValue)
    }

    @objc dynamic var syncing: Bool {
        return bool(forKey: NotificationPropertyKeys.syncingKey.rawValue)
    }
    
    @objc dynamic var childSessionReady: Bool {
        return bool(forKey: NotificationPropertyKeys.childSessionReadyKey.rawValue)
    }
    
    @objc dynamic var childSessionExpired: Bool {
        return bool(forKey: NotificationPropertyKeys.childSessionExpiredKey.rawValue)
    }
    
    @objc dynamic var cryptoServerTime: TimeInterval {
        return double(forKey: NotificationPropertyKeys.cryptoServerTime.rawValue)
    }
}
