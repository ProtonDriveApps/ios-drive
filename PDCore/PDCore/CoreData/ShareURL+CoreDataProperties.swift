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
import CoreData

extension ShareURL {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShareURL> {
        return NSFetchRequest<ShareURL>(entityName: "ShareURL")
    }

    // MARK: - Stored Properties
    @NSManaged public var createTime: Date
    @NSManaged public var creatorEmail: String
    @NSManaged public var expirationTime: Date?
    @NSManaged public var flagsRaw: Int64
    @NSManaged public var lastAccessTime: Date?
    @NSManaged public var maxAccesses: Int
    @NSManaged public var name: String?
    @NSManaged public var numAccesses: Int
    @NSManaged public var password: String
    @NSManaged public var permissionsRaw: Int64
    @NSManaged public var publicUrl: String
    @NSManaged public var share: Share
    @NSManaged public var sharePassphraseKeyPacket: String
    @NSManaged public var sharePasswordSalt: String
    @NSManaged public var srpModulusID: String
    @NSManaged public var srpVerifier: String
    @NSManaged public var id: String
    @NSManaged public var token: String
    @NSManaged public var urlPasswordSalt: String

    // MARK: - Transient Properties
    @NSManaged internal var clearPassword: String?

    // MARK: - Derived properties
    public var shareID: String { share.id }
}
