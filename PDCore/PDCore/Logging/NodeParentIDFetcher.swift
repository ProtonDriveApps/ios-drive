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
import ProtonCoreLog

public final class NodeParentIDFetcher: Sendable {

    // Cached at init so notification handlers can compare coordinators
    // without accessing context properties off its queue.
    private let storage: StorageManager
    private let cache: ParentChainCache
    // SAFETY: var because [weak self] closures require all properties initialized first.
    // Non-Sendable NSObjectProtocol forces the annotation. Set once in init, read in deinit.
    private nonisolated(unsafe) var didSaveObserver: NSObjectProtocol?

    public init(storage: StorageManager) {
        self.storage = storage
        self.cache = ParentChainCache(countLimit: 1000)
        self.didSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleContextDidSave(notification)
        }
    }

    deinit {
        if let didSaveObserver {
            NotificationCenter.default.removeObserver(didSaveObserver)
        }
    }

    public func fetchParentIDs(for nodeID: String) -> [String] {
        let id = NodeIdentifier(rawValue: nodeID)?.nodeID ?? nodeID
        if let cached = cache.get(nodeID: id) {
            return cached
        }
        
        let context = storage.synchronousContextPool.acquire()
        defer { storage.synchronousContextPool.relinquish(context) }
        return context.performAndWait {
            fetchParentIDsSync(for: id, moc: context)
        }
    }

    public func fetchParentIDs(for nodeID: String) async -> [String] {
        let id = NodeIdentifier(rawValue: nodeID)?.nodeID ?? nodeID
        if let cached = cache.get(nodeID: id) {
            return cached
        }

        return await storage.backgroundContextPool.performInContext { moc in
            self.fetchParentIDsSync(for: id, moc: moc)
        }
    }


    private func fetchParentIDsSync(for id: String, moc: NSManagedObjectContext) -> [String] {
        let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1
        fetchRequest.relationshipKeyPathsForPrefetching = ["parentLink"]

        guard let node = try? moc.fetch(fetchRequest).first else {
            return []
        }

        let parentIDs = collectParentIDs(from: node)
        cache.set(nodeID: id, parentChain: parentIDs)
        return parentIDs
    }

    private func handleContextDidSave(_ notification: Notification) {
        guard let sourceContext = notification.object as? NSManagedObjectContext,
              let sourceCoordinator = sourceContext.persistentStoreCoordinator,
              let targetCoordinator = storage.backgroundContext.persistentStoreCoordinator,
              sourceCoordinator === targetCoordinator else { return }

        // Use the notification's userInfo rather than changedValues() — by the time
        // didSave fires, save has already reset change tracking on the context's objects.
        let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        let affectsNodes = updated.contains { $0 is Node }
            || inserted.contains { $0 is Node }
            || deleted.contains { $0 is Node }
        
        if affectsNodes {
            cache.removeAll()
        }
    }

    private func collectParentIDs(from node: Node) -> [String] {
        var parentIDs: [String] = []
        var visited = Set<String>()
        var currentParent = node.parentFolder

        while let parent = currentParent {
            guard visited.insert(parent.id).inserted else {
                Log.error("Cycle detected in parent chain at node \(parent.id)", domain: .metadata)
                break
            }
            parentIDs.append(parent.id)
            currentParent = parent.parentFolder
        }

        return parentIDs
    }

}

// LRU cache for parent-chain lookups.
//
// SAFETY(@unchecked Sendable): All public methods acquire `lock` before
// touching state. `lock` is always a leaf — never held when acquiring another.
final class ParentChainCache: @unchecked Sendable {

    private let lock = NSLock()
    private let countLimit: Int
    private var cache: [String: [String]] = [:]
    private var accessTimestamp: [String: UInt64] = [:]
    private var clock: UInt64 = 0

    init(countLimit: Int) {
        self.countLimit = countLimit
    }

    func get(nodeID: String) -> [String]? {
        lock.lock()
        defer { lock.unlock() }

        guard let chain = cache[nodeID] else { return nil }
        touch(nodeID)
        return chain
    }

    func set(nodeID: String, parentChain: [String]) {
        lock.lock()
        defer { lock.unlock() }

        cache[nodeID] = parentChain
        touch(nodeID)
        evictIfNeeded()
    }


    func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        accessTimestamp.removeAll()
        clock = 0
    }

    private func touch(_ nodeID: String) {
        clock += 1
        accessTimestamp[nodeID] = clock
    }

    // O(n) scan per eviction — acceptable for the expected count limit (~1000).
    private func evictIfNeeded() {
        while cache.count > countLimit {
            guard let oldest = accessTimestamp.min(by: { $0.value < $1.value })?.key else { break }
            accessTimestamp.removeValue(forKey: oldest)
            cache.removeValue(forKey: oldest)
        }
    }
}
