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

public typealias CoreDataInvitation = Invitation

@objc(Invitation)
public class Invitation: NSManagedObject, GloballyUnique {
    @NSManaged public var id: String
    @NSManaged public var invitationID: String
    @NSManaged public var inviterEmail: String
    @NSManaged public var inviteeEmail: String
    @NSManaged public var permissions: Int16
    @NSManaged public var keyPacket: String
    @NSManaged public var keyPacketSignature: String
    @NSManaged public var createTime: Date
    @NSManaged public var shareID: String
    @NSManaged public var volumeID: String
    @NSManaged public var passphrase: String
    @NSManaged public var shareKey: String
    @NSManaged public var creatorEmail: String
    @NSManaged public var type: Int16
    @NSManaged public var linkID: String
    @NSManaged public var name: String
    @NSManaged public var mimeType: String
}
