// Copyright (c) 2026 Proton AG
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
import Foundation

enum ResyncMetadataRepositoryError: Error {
    case missingStoreURL
}

/// Primary `ResyncMetadataRepository` implementation: a small, dedicated CoreData stack living beside the recovery
/// store. Uses its own programmatic model (never the metadata model) so it needs no schema migration and
/// leaves no permanent entity in the crown-jewel store. `inMemory` selects a non-durable in-memory store
/// for fast tests; the on-disk store commits every mutating call, so a fresh instance over the same URL
/// reconstructs the outstanding work after a mid-scan kill.
final class CoreDataResyncMetadataRepository: ResyncMetadataRepository, @unchecked Sendable {
    private enum Entity {
        static let folder = "ScanFolder"
        static let pendingNode = "ScanPendingNode"
        static let state = "ScanState"
    }

    private enum Key {
        static let id = "id"
        static let parentID = "parentID"
        static let depth = "depth"
        static let listingDone = "listingDone"
        static let failed = "failed"
        static let isFolder = "isFolder"
        static let totalNodeCount = "totalNodeCount"
    }

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let storeURL: URL?
    private let inMemory: Bool

    init(storeURL: URL?, inMemory: Bool) throws {
        self.storeURL = storeURL
        self.inMemory = inMemory

        let container = NSPersistentContainer(name: "ResyncMetadataRepository", managedObjectModel: Self.makeModel())
        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            guard let storeURL else { throw ResyncMetadataRepositoryError.missingStoreURL }
            description.type = NSSQLiteStoreType
            description.url = storeURL
        }
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        self.container = container
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.context = context
    }

    // MARK: - Discovery

    func enqueueFoldersForChildrenListing(_ folders: [UnlistedFolder]) async throws {
        guard !folders.isEmpty else { return }
        try await context.perform {
            let existing = self.existingIDs(entity: Entity.folder, ids: folders.map(\.id))
            for folder in folders where !existing.contains(folder.id) {
                let object = self.insert(Entity.folder)
                object.setValue(folder.id, forKey: Key.id)
                object.setValue(folder.parentID, forKey: Key.parentID)
                object.setValue(Int64(folder.depth), forKey: Key.depth)
                object.setValue(false, forKey: Key.listingDone)
                object.setValue(false, forKey: Key.failed)
            }
            try self.context.save()
        }
    }

    func enqueueNodesForMetadataFetching(_ nodes: [PendingNode]) async throws {
        guard !nodes.isEmpty else { return }
        try await context.perform {
            let existing = self.existingIDs(entity: Entity.pendingNode, ids: nodes.map(\.id))
            var newCount = 0
            for node in nodes where !existing.contains(node.id) {
                let object = self.insert(Entity.pendingNode)
                object.setValue(node.id, forKey: Key.id)
                object.setValue(node.parentID, forKey: Key.parentID)
                object.setValue(node.isFolder, forKey: Key.isFolder)
                object.setValue(Int64(node.depth), forKey: Key.depth)
                object.setValue(false, forKey: Key.failed)
                newCount += 1
            }
            self.incrementTotalNodeCount(by: newCount)
            try self.context.save()
        }
    }

    func nextUnlistedFolders(limit: Int) async throws -> [UnlistedFolder] {
        try await context.perform {
            let request = self.fetchRequest(Entity.folder)
            request.predicate = NSPredicate(
                format: "%K == %@ AND %K == %@", Key.listingDone, NSNumber(value: false), Key.failed, NSNumber(value: false)
            )
            request.sortDescriptors = [NSSortDescriptor(key: Key.depth, ascending: true)]
            request.fetchLimit = limit
            return try self.context.fetch(request).map { object in
                UnlistedFolder(
                    id: object.value(forKey: Key.id) as? String ?? "",
                    parentID: object.value(forKey: Key.parentID) as? String,
                    depth: Int((object.value(forKey: Key.depth) as? NSNumber)?.int64Value ?? 0)
                )
            }
        }
    }

    func markChildrenListingDone(folderID: String) async throws {
        try await updateFolder(folderID) { $0.setValue(true, forKey: Key.listingDone) }
    }

    func markChildrenListingFailed(folderID: String) async throws {
        try await updateFolder(folderID) { $0.setValue(true, forKey: Key.failed) }
    }

    // MARK: - Metadata

    func nextPendingFolderIDs(limit: Int) async throws -> [String] {
        try await pendingIDs(isFolder: true, limit: limit)
    }

    func nextPendingFileIDs(limit: Int) async throws -> [String] {
        try await pendingIDs(isFolder: false, limit: limit)
    }

    func markMetadataFetchedAndSaved(_ ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await context.perform {
            let request = self.fetchRequest(Entity.pendingNode)
            request.predicate = NSPredicate(format: "%K IN %@", Key.id, ids)
            for object in try self.context.fetch(request) {
                self.context.delete(object)
            }
            try self.context.save()
        }
    }

    func markMetadataFetchingFailed(_ ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await context.perform {
            let request = self.fetchRequest(Entity.pendingNode)
            request.predicate = NSPredicate(format: "%K IN %@", Key.id, ids)
            for object in try self.context.fetch(request) {
                object.setValue(true, forKey: Key.failed)
            }
            try self.context.save()
        }
    }

    func dropDeletedNodes(_ ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await context.perform {
            let request = self.fetchRequest(Entity.pendingNode)
            request.predicate = NSPredicate(format: "%K IN %@", Key.id, ids)
            let deleted = try self.context.fetch(request)
            for object in deleted {
                self.context.delete(object)
            }
            self.incrementTotalNodeCount(by: -deleted.count)
            try self.context.save()
        }
    }

    // MARK: - State

    /// Kept as a stored running counter rather than a row count because `markMetadataFetchedAndSaved`
    /// deletes saved rows to keep the scratch store small over large trees — so the total of discovered
    /// nodes cannot be derived from the remaining rows.
    func totalNumberOfNodes() async throws -> Int {
        try await context.perform {
            let request = self.fetchRequest(Entity.state)
            request.fetchLimit = 1
            let state = try self.context.fetch(request).first
            return Int((state?.value(forKey: Key.totalNodeCount) as? NSNumber)?.int64Value ?? 0)
        }
    }

    func pendingNodesCount() async throws -> Int {
        try await context.perform {
            let request = self.fetchRequest(Entity.pendingNode)
            request.predicate = NSPredicate(format: "%K == %@", Key.failed, NSNumber(value: false))
            return try self.context.count(for: request)
        }
    }

    func hasOutstandingWork() async throws -> Bool {
        try await context.perform {
            let unlistedFolders = self.fetchRequest(Entity.folder)
            unlistedFolders.predicate = NSPredicate(
                format: "%K == %@ AND %K == %@", Key.listingDone, NSNumber(value: false), Key.failed, NSNumber(value: false)
            )
            if try self.context.count(for: unlistedFolders) > 0 { return true }

            let pending = self.fetchRequest(Entity.pendingNode)
            pending.predicate = NSPredicate(format: "%K == %@", Key.failed, NSNumber(value: false))
            return try self.context.count(for: pending) > 0
        }
    }

    func failedItems() async throws -> [String] {
        try await context.perform {
            var ids: [String] = []
            for entity in [Entity.folder, Entity.pendingNode] {
                let request = self.fetchRequest(entity)
                request.predicate = NSPredicate(format: "%K == %@", Key.failed, NSNumber(value: true))
                ids += try self.context.fetch(request).compactMap { $0.value(forKey: Key.id) as? String }
            }
            // A folder can fail both its children-listing (ScanFolder) and its metadata fetch (ScanPendingNode),
            // matching in both loops; de-duplicate so it is counted once in `RefreshedNodesReport.failed`.
            return Array(Set(ids))
        }
    }

    func markFolderSubtreesFailed(_ folderIDs: [String]) async throws {
        guard !folderIDs.isEmpty else { return }
        try await context.perform {
            // Collect each folder and its transitive descendants by walking parentID over the metadata rows
            // (every discovered node has a pending-node row).
            var idsToFail = Set(folderIDs)
            var frontier = Set(folderIDs)
            while !frontier.isEmpty {
                let request = self.fetchRequest(Entity.pendingNode)
                request.predicate = NSPredicate(format: "%K IN %@", Key.parentID, Array(frontier))
                var children = Set<String>()
                for object in try self.context.fetch(request) {
                    if let id = object.value(forKey: Key.id) as? String { children.insert(id) }
                }
                frontier = children.subtracting(idsToFail)
                idsToFail.formUnion(frontier)
            }
            // Fail the metadata rows only, never the ScanFolder rows: this abandons the subtree's metadata
            // without touching listing state. `failedItems` de-duplicates, so a folder that also failed its
            // own listing is still reported once.
            let markRequest = self.fetchRequest(Entity.pendingNode)
            markRequest.predicate = NSPredicate(format: "%K IN %@", Key.id, Array(idsToFail))
            for object in try self.context.fetch(markRequest) {
                object.setValue(true, forKey: Key.failed)
            }
            try self.context.save()
        }
    }

    func knownFolderIDs(among ids: [String]) async throws -> Set<String> {
        guard !ids.isEmpty else { return [] }
        return try await context.perform {
            let request = self.fetchRequest(Entity.folder)
            request.predicate = NSPredicate(format: "%K IN %@", Key.id, ids)
            return Set(try self.context.fetch(request).compactMap { $0.value(forKey: Key.id) as? String })
        }
    }

    // MARK: - Lifecycle

    func resetFailedItems() async throws {
        try await context.perform {
            for entity in [Entity.folder, Entity.pendingNode] {
                let request = self.fetchRequest(entity)
                request.predicate = NSPredicate(format: "%K == %@", Key.failed, NSNumber(value: true))
                for object in try self.context.fetch(request) {
                    object.setValue(false, forKey: Key.failed)
                }
            }
            try self.context.save()
        }
    }

    func reset() async throws {
        try await context.perform {
            for entity in [Entity.folder, Entity.pendingNode, Entity.state] {
                for object in try self.context.fetch(self.fetchRequest(entity)) {
                    self.context.delete(object)
                }
            }
            try self.context.save()
        }
    }

    func tearDown() async throws {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
        guard !inMemory, let storeURL else { return }
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fileManager.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
    }

    // MARK: - Private operations (each wraps its own `context.perform`)

    private func pendingIDs(isFolder: Bool, limit: Int) async throws -> [String] {
        try await context.perform {
            let request = self.fetchRequest(Entity.pendingNode)
            request.predicate = NSPredicate(
                format: "%K == %@ AND %K == %@", Key.isFolder, NSNumber(value: isFolder), Key.failed, NSNumber(value: false)
            )
            request.sortDescriptors = [NSSortDescriptor(key: Key.depth, ascending: true)]
            request.fetchLimit = limit
            return try self.context.fetch(request).compactMap { $0.value(forKey: Key.id) as? String }
        }
    }

    private func updateFolder(_ id: String, _ mutate: @escaping (NSManagedObject) -> Void) async throws {
        try await context.perform {
            let request = self.fetchRequest(Entity.folder)
            request.predicate = NSPredicate(format: "%K == %@", Key.id, id)
            request.fetchLimit = 1
            guard let object = try self.context.fetch(request).first else { return }
            mutate(object)
            try self.context.save()
        }
    }

    // MARK: - Store helpers (call only from inside a `context.perform` block)

    private func existingIDs(entity: String, ids: [String]) -> Set<String> {
        let request = fetchRequest(entity)
        request.predicate = NSPredicate(format: "%K IN %@", Key.id, ids)
        let results = (try? context.fetch(request)) ?? []
        return Set(results.compactMap { $0.value(forKey: Key.id) as? String })
    }

    private func incrementTotalNodeCount(by delta: Int) {
        guard delta != 0 else { return }
        let request = fetchRequest(Entity.state)
        request.fetchLimit = 1
        let state = (try? context.fetch(request))?.first ?? insert(Entity.state)
        let current = (state.value(forKey: Key.totalNodeCount) as? NSNumber)?.int64Value ?? 0
        state.setValue(current + Int64(delta), forKey: Key.totalNodeCount)
    }

    private func insert(_ entity: String) -> NSManagedObject {
        NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    // MARK: - Pure helper (safe to call anywhere)

    private func fetchRequest(_ entity: String) -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: entity)
    }

    // MARK: - Programmatic model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let folder = entity(Entity.folder, attributes: [
            attribute(Key.id, .stringAttributeType),
            attribute(Key.parentID, .stringAttributeType, optional: true),
            attribute(Key.depth, .integer64AttributeType, defaultValue: 0),
            attribute(Key.listingDone, .booleanAttributeType, defaultValue: false),
            attribute(Key.failed, .booleanAttributeType, defaultValue: false),
        ])
        let pending = entity(Entity.pendingNode, attributes: [
            attribute(Key.id, .stringAttributeType),
            attribute(Key.parentID, .stringAttributeType, optional: true),
            attribute(Key.isFolder, .booleanAttributeType, defaultValue: false),
            attribute(Key.depth, .integer64AttributeType, defaultValue: 0),
            attribute(Key.failed, .booleanAttributeType, defaultValue: false),
        ])
        let state = entity(Entity.state, attributes: [
            attribute(Key.totalNodeCount, .integer64AttributeType, defaultValue: 0),
        ])
        model.entities = [folder, pending, state]
        return model
    }

    private static func entity(_ name: String, attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = attributes
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
