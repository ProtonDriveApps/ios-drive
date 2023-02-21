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

extension Share {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Share> {
        return NSFetchRequest<Share>(entityName: "Share")
    }

    @NSManaged public var addressID: String?
    @NSManaged public var blockSize: Int
    @NSManaged public var creator: String?
    @NSManaged public var id: String
    @NSManaged public var key: String?
    @NSManaged public var passphrase: String?
    @NSManaged public var passphraseSignature: String?
    @NSManaged public var root: Node?
    @NSManaged public var volume: Volume?
    @NSManaged public var shareUrls: Set<ShareURL>
    
    // transient
    @NSManaged internal var clearPassphrase: String?
    
    public var isMain: Bool {
        flags.contains(.main)
    }
}
