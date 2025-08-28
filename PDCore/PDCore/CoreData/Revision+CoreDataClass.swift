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
import PDClient

public typealias CoreDataRevision = Revision

@objc(Revision)
public class Revision: NSManagedObject {
    public typealias NodeState = PDClient.NodeState
    
    @NSManaged private var stateRaw: NSNumber?
    
    @ManagedEnum(raw: #keyPath(stateRaw)) public var state: NodeState?
    
    // dangerous, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._state.configure(with: self)
    }

    override public func prepareForDeletion() {
        super.prepareForDeletion()
        clearUnencryptedContents()
    }
}

public extension Revision {
    func removeOldBlocks(in moc: NSManagedObjectContext) {
        let oldBlocks = blocks
        blocks = Set([])
        oldBlocks.forEach(moc.delete)
    }

    func removeOldThumbnails(in moc: NSManagedObjectContext) {
        let oldThumbnails = thumbnails
        thumbnails = Set([])
        oldThumbnails.forEach(moc.delete)
    }

    // Photos grid only use small thumbnail to display
    // Storing large thumbnails in the database consumes a significant amount of storage space.
    func removeBigThumbnails(in moc: NSManagedObjectContext) {
        let thumbnails = thumbnails.filter { $0.type == .photos }
        for thumbnail in thumbnails {
            try? thumbnail.clearBlob(in: moc)
        }
    }
}
