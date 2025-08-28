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

import CoreData

public typealias CoreDataDevice = Device

@objc(Device)
public class Device: NSManagedObject, VolumeUnique {
    @NSManaged public var id: String
    @NSManaged public var volumeID: String
    @NSManaged public var createTime: Date
    @NSManaged public var modifyTime: Date?
    @NSManaged public var lastSyncTime: Date?
    @NSManaged public var type: ´Type´
    @NSManaged public var syncState: SyncState

    // MARK: - Relationships
    @NSManaged public var volume: Volume
    @NSManaged public var share: Share

    @objc public enum ´Type´: Int16 {
        case windows = 1
        case macOS = 2
        case linux = 3
    }

    @objc public enum SyncState: Int16 {
        case off = 0
        case on = 1
    }

    public func decryptedName() throws -> String {
        guard let root = share.root else {
            throw self.invalidState("Device name could not be decrypted, because it has no root defined")
        }

        return try root.decryptName()
    }
}
