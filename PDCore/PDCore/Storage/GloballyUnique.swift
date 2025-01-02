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

import Foundation
import CoreData

public protocol GloballyUnique: NSManagedObject {
    var id: String { get set }
}

extension GloballyUnique {
    // Method to fetch or create multiple entities based on a collection of IDs
    public static func fetchOrCreate(ids: Set<String>, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> [Self] {
        // Fetch existing entities that match the given IDs
        let existingEntities = fetch(ids: ids, allowSubclasses: allowSubclasses, in: context)
        var resultEntities: [Self] = existingEntities

        // Determine which IDs are missing (i.e., don't have an existing entity)
        let existingIDs = Set(existingEntities.compactMap { $0.value(forKey: "id") as? String })
        let missingIDs = ids.subtracting(existingIDs)

        // Create new entities for the missing IDs
        for id in missingIDs {
            let newEntity = new(id: id, in: context)
            resultEntities.append(newEntity)
        }

        return resultEntities
    }

    // Method to fetch multiple entities based on a collection of IDs
    public static func fetch(ids: Set<String>, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> [Self] {
        let fetchRequest = NSFetchRequest<Self>(entityName: entity().name!)

        if allowSubclasses {
            fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
        } else {
            fetchRequest.predicate = NSPredicate(format: "self.entity == %@ AND id IN %@", entity(), ids)
        }

        return (try? context.fetch(fetchRequest)) ?? []
    }

    public static func fetchOrCreate(id: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self {
        if let existingEntity = fetch(id: id, allowSubclasses: allowSubclasses, in: context) {
            return existingEntity
        }
        return new(id: id, in: context)
    }

    public static func fetch(id: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self? {
        let fetchRequest = NSFetchRequest<Self>(entityName: entity().name!)
        fetchRequest.fetchLimit = 1

        if allowSubclasses {
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        } else {
            fetchRequest.predicate = NSPredicate(format: "self.entity == %@ AND id == %@", entity(), id)
        }
        return try? context.fetch(fetchRequest).first
    }

    public static func new(id: String, in context: NSManagedObjectContext) -> Self {
        let newEntity = NSEntityDescription.insertNewObject(forEntityName: entity().name!, into: context) as! Self
        newEntity.setValue(id, forKey: "id")
        return newEntity
    }

}
