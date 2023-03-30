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

extension Revision {
    func removeOldBlocks(in moc: NSManagedObjectContext) {
        let oldBlocks = blocks
        blocks = Set([])
        oldBlocks.forEach(moc.delete)
    }

    func removeOldThumbnail(in moc: NSManagedObjectContext) {
        if let oldThumbnail = thumbnail {
            thumbnail = nil
            moc.delete(oldThumbnail)
        }
    }
}

extension StorageManager {
    func removeOldBlocks(of revisionObj: PDCore.Revision) {
        let oldBlocks = revisionObj.blocks
        let moc = revisionObj.managedObjectContext!
        moc.performAndWait {
            revisionObj.blocks = Set([])
            oldBlocks.forEach(moc.delete)
        }
    }
}

// MARK: - Generic NSManagedObject methods

extension StorageManager {
    /// Returns list of objects with named ids, finds present ones and creates new ones for missing ids
    internal func unique<Entity: NSManagedObject>(with ids: Set<String>,
                                                  uniqueBy keyPath: String = "id",
                                                  in moc: NSManagedObjectContext) -> [Entity]
    {
        let existing: [Entity] = self.existing(with: ids, by: keyPath, in: moc)
        var presentObjects: [Entity] = existing
        
        let presentIds = Set(presentObjects.compactMap { $0.value(forKey: keyPath) as? String })
        let newIds = Set(ids).subtracting(presentIds)
        
        let newObjects: [Entity] = newIds.map { self.new(with: $0, by: keyPath, in: moc) }
        presentObjects.append(contentsOf: newObjects)
        
        return presentObjects
    }
    
    /// Creates new object with named id
    public func new<Entity: NSManagedObject>(with id: String,
                                             by keyPath: String,
                                             in moc: NSManagedObjectContext) -> Entity
    {
        let new = NSEntityDescription.insertNewObject(forEntityName: Entity.entity().managedObjectClassName, into: moc)
        new.setValue(id, forKey: keyPath)
        return new as! Entity
    }
    
    internal func existing<Entity: NSManagedObject>(with ids: Set<String>,
                                                    by keyPath: String = "id",
                                                    in moc: NSManagedObjectContext) -> [Entity]
    {
        let fetchRequest = NSFetchRequest<Entity>()
        fetchRequest.entity = Entity.entity()
        fetchRequest.predicate = NSPredicate(format: "(self.entity == %@ AND %K IN %@)", Entity.entity(), keyPath, ids)
        return (try? moc.fetch(fetchRequest) ) ?? []
    }
    
    internal func exists(with id: String,
                         by keyPath: String = "id",
                         in moc: NSManagedObjectContext) -> Bool
    {
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Node")
        fetchRequest.predicate = NSPredicate(format: "(%K IN %@)", keyPath, [id])
        fetchRequest.includesSubentities = true
        fetchRequest.resultType = .countResultType
        
        do {
            let count = try moc.fetch(fetchRequest)
            return count.first?.intValue != 0
        } catch let error {
            assert(false, error.localizedDescription)
            return false
        }
    }
}
