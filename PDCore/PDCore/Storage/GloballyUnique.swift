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
        fetchOrCreateIndicatingResult(ids: ids, allowSubclasses: allowSubclasses, in: context).map(\.value)
    }
    
    // Method to fetch or create multiple entities based on a collection of IDs, passing the info whether the entity was fetched or created to caller
    public static func fetchOrCreateIndicatingResult(
        ids: Set<String>, allowSubclasses: Bool = false, in context: NSManagedObjectContext
    ) -> [FetchOrCreateResult<Self>] {
        // Fetch existing entities that match the given IDs
        let existingEntities = fetch(ids: ids, allowSubclasses: allowSubclasses, in: context)
        var resultEntities: [FetchOrCreateResult<Self>] = existingEntities.map(FetchOrCreateResult.fetched)

        // Determine which IDs are missing (i.e., don't have an existing entity)
        let existingIDs = Set(existingEntities.map(\.id))
        let missingIDs = ids.subtracting(existingIDs)

        // Create new entities for the missing IDs
        for id in missingIDs {
            let newEntity = new(id: id, in: context)
            resultEntities.append(.created(newEntity))
        }

        return resultEntities
    }

    // Method to fetch multiple entities based on a collection of IDs
    public static func fetch(ids: Set<String>, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> [Self] {
        let entityName = entity().name!
        let fetchRequest = NSFetchRequest<Self>(entityName: entityName)

        if allowSubclasses {
            fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
        } else {
            fetchRequest.predicate = NSPredicate(format: "id IN %@ AND self.entity == %@", ids, entity())
        }

        let results = (try? context.fetch(fetchRequest)) ?? []
        
        // wrapped in the check to avoid the performance penalty on fetch in the prod builds
        if Constants.buildType.isBetaOrBelow {
            let duplicateIds = Dictionary(grouping: results, by: \.id).filter { $1.count > 1 }.keys
            duplicateIds.forEach {
                assertionFailure("There should not be more than one globally unique entity with a particular id")
                Log.warning("Multiple entities found for globally unique entity \(entityName) with id \($0)", domain: .metadata, sendToSentryIfPossible: true)
            }
        }
        
        return results
    }

    public static func fetchOrCreate(id: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self {
        fetchOrCreateIndicatingResult(id: id, allowSubclasses: allowSubclasses, in: context).value
    }
    
    public static func fetchOrCreateIndicatingResult(id: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> FetchOrCreateResult<Self> {
        if let existingEntity = fetch(id: id, allowSubclasses: allowSubclasses, in: context) {
            return .fetched(existingEntity)
        }
        return .created(new(id: id, in: context))
    }

    public static func fetch(id: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self? {
        let entityName = entity().name!
        let fetchRequest = NSFetchRequest<Self>(entityName: entityName)

        if allowSubclasses {
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        } else {
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND self.entity == %@", id, entity())
        }

        guard let fetched = try? context.fetch(fetchRequest) else {
            return nil
        }
        if fetched.count > 1 {
            assertionFailure("There should not be more than one globally unique entity with a particular id")
            Log.warning("Multiple entities found for globally unique entity \(entityName) with id \(id)", domain: .metadata, sendToSentryIfPossible: true)
        }
        return fetched.first
    }

    public static func new(id: String, in context: NSManagedObjectContext) -> Self {
        let newEntity = NSEntityDescription.insertNewObject(forEntityName: entity().name!, into: context) as! Self
        newEntity.setValue(id, forKey: "id")
        return newEntity
    }

    // Method to fetch an entity based on VolumeIdentifier, throwing an error if not found
    public static func fetchOrThrow(id: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) throws -> Self {
        guard let entity = fetch(id: id, allowSubclasses: allowSubclasses, in: context) else {
            throw DriveError("with id \(id) should have been saved, but was not found in store.")
        }
        return entity
    }
}
