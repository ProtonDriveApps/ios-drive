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

import CoreData

public protocol SyncErrorHandling {
    func handleUpdate(context: NSManagedObjectContext) async -> NSManagedObjectID
}

public enum EntityWithChangeType<Entity> {
    case insert(Entity)
    case update(Entity)
    case delete(String)
}

public class CoreDataCommunicationService<Entity: NSManagedObject>: CommunicationServiceListener {

    public typealias Update = EntityWithChangeType<Entity>

    private let suite: SettingsStorageSuite
    private var updatesContinuations: [UUID: AsyncStream<EntityWithChangeType<Entity>>.Continuation] = [:]
    private let historyObserver: PersistentHistoryObserver
    private let entityType: Entity.Type
    private var updatesTask: Task<(), Never>?
    private let includeHistory: Bool

    public var updates: AsyncStream<EntityWithChangeType<Entity>> {
        AsyncStream<EntityWithChangeType<Entity>> { [weak self] continuation in
            let uuid = UUID()
            continuation.onTermination = { [weak self] _ in // we don't care about the termination reason
                self?.updatesContinuations.removeValue(forKey: uuid)
            }
            if self?.includeHistory == true {
                self?.fetchAllEntitiesFromPersistentStore { item in
                    continuation.yield(.insert(item))
                }
            }
            self?.updatesContinuations[uuid] = continuation
        }
    }

    public let moc: NSManagedObjectContext
    
    public init(suite: SettingsStorageSuite,
                entityType: Entity.Type,
                historyObserver: PersistentHistoryObserver,
                context: NSManagedObjectContext,
                includeHistory: Bool) {
        self.suite = suite
        self.historyObserver = historyObserver
        self.entityType = entityType
        self.moc = context
        self.includeHistory = includeHistory
        
        historyObserver.clean(everything: true)

        // Setup and start observing persistent history changes
        startObservingCoreDataChanges()
    }

    private func startObservingCoreDataChanges() {
        let historyObserver = historyObserver
        updatesTask = Task { [weak self] in
            historyObserver.startObserving()
            for await transactions in historyObserver.transactions {
                guard !Task.isCancelled else { return }
                await self?.moc.perform { [weak self] in
                    for transaction in transactions {
                        self?.processTransaction(transaction)
                    }
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    private func processTransaction(_ transaction: NSPersistentHistoryTransaction) {
        guard let changes = transaction.changes else { return }

        for change in changes where change.changedObjectID.entity.name == self.entityType.entity().name {
            let changedObjectID = change.changedObjectID
            switch change.changeType {
            case .insert:
                let entityObject = moc.object(with: changedObjectID)
                if let entityObject = entityObject as? Entity {
                    let item: EntityWithChangeType<Entity> = .insert(entityObject)
                    updatesContinuations.values.forEach {
                        $0.yield(item)
                    }
                }
            case .update:
                let entityObject = moc.object(with: changedObjectID)
                if let entityObject = entityObject as? Entity {
                    let item: EntityWithChangeType<Entity> = .update(entityObject)
                    updatesContinuations.values.forEach {
                        $0.yield(item)
                    }
                }
            case .delete:
                let item: EntityWithChangeType<Entity> = .delete(changedObjectID.uriRepresentation().absoluteString)
                updatesContinuations.values.forEach {
                    $0.yield(item)
                }

            @unknown default:
                Log.error("Unknown case for NSPersistentHistoryChangeType", domain: .ipc)
            }
        }
    }

    private func fetchAllEntitiesFromPersistentStore(_ operation: (Entity) -> Void) {
        moc.performAndWait {
            let fetchRequest = NSFetchRequest<Entity>()
            fetchRequest.entity = Entity.entity()
            if let result = try? moc.fetch(fetchRequest) {
                result.forEach(operation)
            }
        }
    }
}
