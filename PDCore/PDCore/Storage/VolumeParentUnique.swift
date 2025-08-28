// Copyright (c) 2025 Proton AG
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

public protocol VolumeParentUnique: NSManagedObject {
    var id: String { get }
    var volumeID: String { get }
    var parentID: String? { get }

    static var parentIDKeyPath: String { get }
}

public protocol VolumeParentIdentifiable: Hashable {
    var id: String { get }
    var volumeID: String { get }
    var parentID: String? { get }
}

extension VolumeParentUnique {
    // Method to fetch or create an entity based on VolumeIdentifier
    public static func fetchOrCreate(identifier: any VolumeParentIdentifiable, in context: NSManagedObjectContext) -> Self {
        if let result = fetch(identifier: identifier, in: context) {
            return result
        } else {
            return makeNew(identifier: identifier, in: context)
        }
    }

    // Method to create a new entity
    static func makeNew(identifier: any VolumeParentIdentifiable, in context: NSManagedObjectContext) -> Self {
        let newEntity = NSEntityDescription.insertNewObject(forEntityName: entity().name!, into: context) as! Self
        newEntity.setValue(identifier.id, forKey: "id")
        newEntity.setValue(identifier.volumeID, forKey: "volumeID")
        newEntity.setValue(identifier.parentID, forKey: Self.parentIDKeyPath)
        return newEntity
    }

    // Method to fetch an entity
    public static func fetch(identifier: any VolumeParentIdentifiable, in context: NSManagedObjectContext) -> Self? {
        let fetchRequest = NSFetchRequest<Self>(entityName: entity().name!)
        fetchRequest.fetchLimit = 1
        var predicates = [
            NSPredicate(format: "id == %@", identifier.id),
            NSPredicate(format: "volumeID == %@", identifier.volumeID)
        ]
        if let parentID = identifier.parentID {
            predicates.append(NSPredicate(format: "%K == %@", Self.parentIDKeyPath, parentID))
        } else {
            predicates.append(NSPredicate(format: "%K == nil", Self.parentIDKeyPath))
        }
        // the self.entity predicate has to be last in the compound predicate because of macOS 26 bug (tested on dev beta 1 and beta 2)
        predicates.append(NSPredicate(format: "self.entity == %@", entity()))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return try? context.fetch(fetchRequest).first
    }

    // Method to fetch all by id + volumeID -> can return mutliple results, since the identifier isn't unique
    public static func fetchAll(identifier: any VolumeIdentifiable, in context: NSManagedObjectContext) -> [Self] {
        let fetchRequest = NSFetchRequest<Self>(entityName: entity().name!)
        fetchRequest.fetchLimit = 1
        let predicates = [
            NSPredicate(format: "id == %@", identifier.id),
            NSPredicate(format: "volumeID == %@", identifier.volumeID),
            NSPredicate(format: "self.entity == %@", entity())
        ]
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return (try? context.fetch(fetchRequest)) ?? []
    }
}
