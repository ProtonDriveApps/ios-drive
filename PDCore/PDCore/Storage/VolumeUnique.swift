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

public protocol VolumeUnique: NSManagedObject {
    var id: String { get set }
    var volumeID: String { get set }
}

public struct AnyVolumeIdentifier: VolumeIdentifiable, Equatable {

    public let id: String
    public let volumeID: String

    public init(id: String, volumeID: String) {
        self.id = id
        self.volumeID = volumeID
    }

}

public protocol VolumeIdentifiable: Hashable {
    var id: String { get }
    var volumeID: String { get }
}

extension VolumeUnique {
    // Method to fetch or create an entity based on VolumeIdentifier
    public static func fetchOrCreate(identifier: any VolumeIdentifiable, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self {
        return fetchOrCreate(id: identifier.id, volumeID: identifier.volumeID, allowSubclasses: allowSubclasses, in: context)
    }

    // Method to fetch or create multiple entities based on a set of VolumeIdentifier
    public static func fetchOrCreate<T: VolumeIdentifiable & Hashable>(identifiers: Set<T>, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> [Self] {
        var resultEntities: [Self] = []

        for identifier in identifiers {
            let entity = fetchOrCreate(id: identifier.id, volumeID: identifier.volumeID, allowSubclasses: allowSubclasses, in: context)
            resultEntities.append(entity)
        }

        return resultEntities
    }

    // Method to fetch an entity based on VolumeIdentifier
    public static func fetch(identifier: any VolumeIdentifiable, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self? {
        return fetch(id: identifier.id, volumeID: identifier.volumeID, allowSubclasses: allowSubclasses, in: context)
    }

    // Method to fetch an entity based on VolumeIdentifier, throwing an error if not found
    public static func fetchOrThrow<T: NSManagedObject>(identifier: any VolumeIdentifiable, allowSubclasses: Bool = false, in context: NSManagedObjectContext) throws -> T {
        guard let entity = fetch(id: identifier.id, volumeID: identifier.volumeID, allowSubclasses: allowSubclasses, in: context) as? T else {
            throw DriveError("\(T.self) with id \(identifier) should have been saved, but was not found in store.")
        }
        return entity
    }

    // Method to fetch multiple entities based on a set of VolumeIdentifier
    public static func fetch<T: VolumeIdentifiable & Hashable>(identifiers: Set<T>, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> [Self] {
        var resultEntities: [Self] = []
        for identifier in identifiers {
            if let entity = fetch(id: identifier.id, volumeID: identifier.volumeID, allowSubclasses: allowSubclasses, in: context) {
                resultEntities.append(entity)
            }
        }
        return resultEntities
    }

    // Method to create a new entity
    static func new(id: String, volumeID: String, in context: NSManagedObjectContext) -> Self {
        let newEntity = NSEntityDescription.insertNewObject(forEntityName: entity().name!, into: context) as! Self
        newEntity.setValue(id, forKey: "id")
        newEntity.setValue(volumeID, forKey: "volumeID")
        return newEntity
    }

    // Method to fetch or create an entity
    public static func fetchOrCreate(id: String, volumeID: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self {
        if let existingEntity = fetch(id: id, volumeID: volumeID, allowSubclasses: allowSubclasses, in: context) {
            return existingEntity
        }
        return new(id: id, volumeID: volumeID, in: context)
    }

    // Method to fetch or create multiple entities
    public static func fetchOrCreate(ids: Set<String>, volumeID: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> [Self] {
        let existingEntities = fetch(ids: ids, volumeID: volumeID, allowSubclasses: allowSubclasses, in: context)
        var resultEntities: [Self] = existingEntities

        let existingIDs = Set(existingEntities.compactMap { $0.value(forKey: "id") as? String })
        let missingIDs = ids.subtracting(existingIDs)

        for id in missingIDs {
            let newEntity = new(id: id, volumeID: volumeID, in: context)
            resultEntities.append(newEntity)
        }

        return resultEntities
    }

    // Method to fetch an entity
    public static func fetch(id: String, volumeID: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Self? {
        let fetchRequest = NSFetchRequest<Self>(entityName: entity().name!)
        fetchRequest.fetchLimit = 1

        if allowSubclasses {
            fetchRequest.predicate = NSPredicate(format: "id == %@ AND volumeID == %@", id, volumeID)
        } else {
            fetchRequest.predicate = NSPredicate(format: "self.entity == %@ AND id == %@ AND volumeID == %@", entity(), id, volumeID)
        }

        return try? context.fetch(fetchRequest).first
    }

    // Method to fetch multiple entities
    public static func fetch(ids: Set<String>, volumeID: String, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> [Self] {
        let fetchRequest = NSFetchRequest<Self>(entityName: entity().name!)

        if allowSubclasses {
            fetchRequest.predicate = NSPredicate(format: "id IN %@ AND volumeID == %@", ids, volumeID)
        } else {
            fetchRequest.predicate = NSPredicate(format: "self.entity == %@ AND id IN %@ AND volumeID == %@", entity(), ids, volumeID)
        }

        return (try? context.fetch(fetchRequest)) ?? []
    }
}
