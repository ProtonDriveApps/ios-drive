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

import CoreData

public typealias CoreDataMembership = Membership

@objc(Membership)
public class Membership: NSManagedObject, GloballyUnique {
    @NSManaged public var id: String
    @NSManaged public var shareID: String
    @NSManaged public var addressID: String
    @NSManaged public var addressKeyID: String
    @NSManaged public var inviter: String
    @NSManaged public var permissions: Int16
    @NSManaged public var keyPacket: String
    @NSManaged public var keyPacketSignature: String
    @NSManaged public var sessionKeySignature: String
    @NSManaged public var state: Int16
    @NSManaged public var createTime: Date
    @NSManaged public var modifyTime: Date

    // Relationships
    @NSManaged public var Share: Share
}

import PDClient

extension Membership {
    public func fullfill(membership: ShareMetadata.Membership) {
        self.id = membership.memberID
        self.shareID = membership.shareID
        self.addressID = membership.addressID
        self.addressKeyID = membership.addressKeyID
        self.inviter = membership.inviter
        self.permissions = Int16(membership.permissions)
        self.keyPacket = membership.keyPacket
        self.keyPacketSignature = membership.keyPacketSignature ?? ""
        self.sessionKeySignature = membership.sessionKeySignature ?? ""
        self.state = Int16(membership.state)
        self.createTime = Date(timeIntervalSince1970: TimeInterval(membership.createTime))
        self.modifyTime = Date(timeIntervalSince1970: TimeInterval(membership.modifyTime))
    }
}
