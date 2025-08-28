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
import ProtonCoreUtilities

// TODO: unify base class with StorageManager after PDFileSystemEvents.framework will be merged with PDCore
public class EventStorageManager: NSObject, RecoverableStorage {
    public typealias Entry = [String: Any]
    public typealias ProviderType = String
    public typealias ShareID = String
    public typealias EventID = String
    
    private static let databaseName = "EventStorageModel"
    public var previousRunWasInterrupted = false

    private static let managedObjectModel: NSManagedObjectModel = {
        // static linking
        if let resources = Bundle.main.resourceURL?.appendingPathComponent("PDCoreResources").appendingPathExtension("bundle"),
           let bundle = Bundle(url: resources)?.url(forResource: databaseName, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: bundle)
        {
            return model
        }
        
        #if RESOURCES_ARE_IMPORTED_BY_SPM
        if let bundle = Bundle.module.url(forResource: databaseName, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: bundle)
        {
            return model
        }
        #endif
        
        // dynamic linking
        if let bundle = Bundle(for: EventStorageManager.self).url(forResource: databaseName, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: bundle)
        {
            return model
        }
        
        fatalError("Error loading EventStorageModel from bundle")
    }()
    
    internal static func defaultPersistentContainer(suiteUrl: URL?) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: databaseName, managedObjectModel: self.managedObjectModel)
        
        let storeDirectoryUrl = suiteUrl ?? NSPersistentContainer.defaultDirectoryURL()
        let storeFileUrl = storeDirectoryUrl.appendingPathComponent(databaseName + ".sqlite")
        
        let storeDescription = NSPersistentStoreDescription(url: storeFileUrl)
        storeDescription.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            do {
                try FileManager.default.secureFilesystemItems(storeFileUrl)
            } catch {
                assertionFailure(error.localizedDescription)
            }
            
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }

    private static func inMemoryPersistantContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: databaseName, managedObjectModel: self.managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false // Make it simpler in test env

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { (description, error) in
            // Check if the data store is in memory
            precondition( description.type == NSInMemoryStoreType )

            // Check if creating container wrong
            if let error = error {
                fatalError("Create an in-memory coordinator failed \(error)")
            }
        }

        return container
    }
    
    private static func inMemoryPersistantContainer(prePopulatedFrom databaseUrl: URL) -> NSPersistentContainer {
        let container = Self.defaultPersistentContainer(suiteUrl: databaseUrl)
        let coordinator = container.persistentStoreCoordinator
        coordinator.persistentStores.forEach { persistentStore in
            do {
                try coordinator.migratePersistentStore(persistentStore, to: NSPersistentContainer.defaultDirectoryURL(), options: nil, withType: NSInMemoryStoreType)
            } catch let error {
                fatalError("Error while migrating persistentStore \(error)")
            }
        }
        return container
    }

    private let persistentContainer: NSPersistentContainer

    private lazy var backgroundContext: NSManagedObjectContext = makeNewBackgroundContext()

    public func makeNewBackgroundContext() -> NSManagedObjectContext {
        let context = self.persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
#if os(macOS)
        Self.keepWeakReferenceToContext(context, in: contexts)
#endif
        return context
    }
    
    private static let recoveryDatabaseName = "Recovery_\(databaseName)"
    static let backupDatabaseName = "Backup_\(databaseName)"
    let contexts: Atomic<[WeakReference<NSManagedObjectContext>]> = .init([])
    public func disconnectExistingDB() throws -> PersistentStoreInfo {
        try Self.disconnectExistingDB(named: Self.databaseName, using: persistentContainer, contexts: contexts)
    }
    public func createRecoveryDB(nextTo backup: PersistentStoreInfo) throws -> PersistentStoreInfo {
        try Self.createRecoveryDB(named: Self.recoveryDatabaseName, nextTo: backup, using: persistentContainer)
    }
    public func reconnectExistingDBAndDiscardRecoveryIfNeeded(existing: PersistentStoreInfo, recovery: PersistentStoreInfo?) throws {
        try Self.reconnectExistingDBAndDiscardRecoveryIfNeeded(existing: existing, recovery: recovery, using: persistentContainer, contexts: contexts)
    }
    public func replaceExistingDBWithRecovery(existing: PersistentStoreInfo, recovery: PersistentStoreInfo) throws {
        try Self.replaceExistingDBWithRecovery(
            backupName: Self.backupDatabaseName, existing: existing, recovery: recovery, using: persistentContainer, contexts: contexts
        )
    }
    @discardableResult
    public func cleanupLeftoversFromPreviousRecoveryAttempt() -> Bool {
        Self.cleanupLeftoversFromPreviousRecoveryAttempt(
            existingName: Self.databaseName, recoveryName: Self.recoveryDatabaseName, backupName: Self.backupDatabaseName, using: persistentContainer
        )
    }
    public func moveExistingDBToBackup(existing: PersistentStoreInfo) throws -> PersistentStoreInfo {
        try Self.moveExistingDBToBackup(
            backupName: Self.backupDatabaseName, existing: existing, using: persistentContainer, contexts: contexts
        )
    }
    public func restoreFromBackup() throws {
        try Self.restoreFromBackup(backupName: Self.backupDatabaseName, existingName: Self.databaseName, using: persistentContainer)
    }

    public init(prePopulateFrom template: URL?) {
        if let template {
            self.persistentContainer = Self.inMemoryPersistantContainer(prePopulatedFrom: template)
        } else {
            self.persistentContainer = Self.inMemoryPersistantContainer()
        }
        super.init()
    }
    
    public init(suiteUrl: URL) {
        self.persistentContainer = Self.defaultPersistentContainer(suiteUrl: suiteUrl)
        super.init()
        
        do {
            try restoreFromBackup()
            cleanupLeftoversFromPreviousRecoveryAttempt()
        } catch {
            Log.error("Restoring from backup failed", error: error, domain: .storage)
        }
        
        #if DEBUG
        // swiftlint:disable no_print
        print("💠 EventsCoreData model located at: \(self.persistentContainer.persistentStoreCoordinator.persistentStores)")
        // swiftlint:enable no_print
        #endif
    }
}

extension EventStorageManager {
    public func persist(events: Zip2Sequence<[GenericEvent], [Data]>, provider: ProviderType) {
        self.backgroundContext.performAndWait {
            events.forEach { event, packedOriginal in
                let new = NSEntityDescription.insertNewObject(forEntityName: PersistedEvent.entity().managedObjectClassName, into: self.backgroundContext)
                
                new.setValue(provider, forKey: #keyPath(PersistedEvent.providerType))
                new.setValue(event.shareId, forKey: #keyPath(PersistedEvent.shareId))
                new.setValue(packedOriginal, forKey: #keyPath(PersistedEvent.contents))
                new.setValue(event.eventId, forKey: #keyPath(PersistedEvent.eventId))
                new.setValue(event.eventEmittedAt, forKey: #keyPath(PersistedEvent.eventEmittedAt))
                new.setValue(event.volumeId, forKey: #keyPath(PersistedEvent.volumeId))
            }
            
            do {
                try self.backgroundContext.saveOrRollback()
            } catch let error {
                assert(false, error.localizedDescription)
            }
        }
    }
    
    public func disregard(_ objectID: NSManagedObjectID) {
        self.backgroundContext.performAndWait {
            guard let object = self.backgroundContext.object(with: objectID) as? PersistedEvent else { return }
            object.isProcessed = true
            object.isEnumerated = true
            try? self.backgroundContext.saveOrRollback()
        }
    }
    
    public func discard(_ objectID: NSManagedObjectID) {
        self.backgroundContext.performAndWait {
            let object = self.backgroundContext.object(with: objectID) as? PersistedEvent
            // we need to keep events for EventListeners
            object?.isProcessed = true
            try? self.backgroundContext.saveOrRollback()
        }
    }
    
    public func setEnumerated(_ objectIDs: [NSManagedObjectID]) {
        self.backgroundContext.performAndWait {
            objectIDs.forEach { objectID in
                let object = self.backgroundContext.object(with: objectID) as? PersistedEvent
                object?.isEnumerated = true
            }
            try? self.backgroundContext.saveOrRollback()
        }
    }

    public func queue(volumeId: String) -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = self.requestEvents(excludeIsProcessedEqualTo: true, volumeId: volumeId)
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: self.backgroundContext,
                                                    sectionNameKeyPath: nil,
                                                    cacheName: nil)
        
        do {
            try controller.performFetch()
        } catch {
            assert(false, error.localizedDescription)
        }
        
        return controller
    }
    
    private func baseRequest() -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = PersistedEvent.entity()
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.returnsDistinctResults = true
        fetchRequest.sortDescriptors = [.init(key: #keyPath(PersistedEvent.eventEmittedAt), ascending: true)]
        
        let objectId = NSExpressionDescription()
        objectId.name = #keyPath(PersistedEvent.objectID)
        objectId.expression = NSExpression.expressionForEvaluatedObject()
        objectId.expressionResultType = NSAttributeType.objectIDAttributeType
        
        fetchRequest.propertiesToFetch = [#keyPath(PersistedEvent.shareId),
                                          #keyPath(PersistedEvent.contents),
                                          objectId,
                                          #keyPath(PersistedEvent.providerType)]
        return fetchRequest
    }
    
    private func requestEvents(since lowerTimestamp: TimeInterval? = nil,
                               until higherTimestamp: TimeInterval? = nil,
                               excludeIsProcessedEqualTo: Bool? = nil,
                               excludeIsEnumeratedEqualTo: Bool? = nil,
                               volumeId: String?) -> NSFetchRequest<NSFetchRequestResult>
    {
        // this predicate is critical to exclude repetitive processing of same events
        // because events are not deleted after processing - we need to keep them for EventListeners
        var subpredicates = [NSPredicate]()
        if let lower = lowerTimestamp {
            subpredicates.append(NSPredicate(format: "%K >= %@", #keyPath(PersistedEvent.eventEmittedAt), NSNumber(value: lower)))
        }
        if let higher = higherTimestamp {
            subpredicates.append(NSPredicate(format: "%K <= %@", #keyPath(PersistedEvent.eventEmittedAt), NSNumber(value: higher)))
        }
        if let excluding = excludeIsProcessedEqualTo {
            subpredicates.append(NSPredicate(format: "%K != %@", #keyPath(PersistedEvent.isProcessed), NSNumber(value: excluding)))
        }
        if let excluding = excludeIsEnumeratedEqualTo {
            subpredicates.append(NSPredicate(format: "%K != %@", #keyPath(PersistedEvent.isEnumerated), NSNumber(value: excluding)))
        }
        if let volumeId {
            subpredicates.append(NSPredicate(format: "%K == %@", #keyPath(PersistedEvent.volumeId), volumeId))
        }

        let fetchRequest = self.baseRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        return fetchRequest
    }
    
    public func clearUp(volumeId: String) {
        self.backgroundContext.performAndWait {
            self.backgroundContext.reset()
            
            [PersistedEvent.self].forEach { entity in
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity))
                fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(PersistedEvent.volumeId), volumeId)
                let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                _ = try? self.persistentContainer.persistentStoreCoordinator.execute(request, with: self.backgroundContext)
            }
        }
    }

    public func count() throws -> Int {
        let fetchRequest = NSFetchRequest<PersistedEvent>()
        fetchRequest.entity = PersistedEvent.entity()
        
        return try backgroundContext.performAndWait {
            try backgroundContext.count(for: fetchRequest)
        }
    }
    
    public func unprocessedEventCount(volumeId: String) throws -> Int {
        let fetchRequest = NSFetchRequest<PersistedEvent>()
        fetchRequest.entity = PersistedEvent.entity()
        fetchRequest.predicate = NSPredicate(
            format: "%K == %@ && %K == %@",
            #keyPath(PersistedEvent.isProcessed), NSNumber(value: false),
            #keyPath(PersistedEvent.volumeId), volumeId
        )

        let context = self.persistentContainer.viewContext
        return try context.performAndWait {
            try context.count(for: fetchRequest)
        }
    }
    
    // Deletes all processed events (from all volumes) up to the given horizon. 
    public func periodicalCleanup(horizon: DateComponents = .init(day: -10)) throws {
        guard let horizonDate = Calendar.current.date(byAdding: horizon, to: Date()) else {
            return
        }
        let fetchRequest = self.requestEvents(until: horizonDate.timeIntervalSince1970, excludeIsProcessedEqualTo: false, volumeId: nil)
        fetchRequest.resultType = .managedObjectResultType
        fetchRequest.propertiesToFetch = nil
                
        var errorToThrow: Error?
        self.backgroundContext.performAndWait {
            do {
                try self.backgroundContext.fetch(fetchRequest)
                    .compactMap { $0 as? NSManagedObject }
                    .forEach(self.backgroundContext.delete)
                try self.backgroundContext.saveOrRollback()
            } catch let error {
                errorToThrow = error
            }
        }
        guard errorToThrow == nil else { throw errorToThrow! }
            
        // TODO: In-memory stores are not supported by NSBatchDeleteRequest, so unit testing on current test dataset is difficult
        /*
            let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            request.resultType = .resultTypeObjectIDs
            _ = try self.persistentContainer.persistentStoreCoordinator.execute(request, with: self.backgroundContext)
         */
    }

    public func fetchUnprocessedEvents(volumeId: String, managedObjectContext: NSManagedObjectContext) async throws -> [PersistedEvent] {
        let fetchRequest = NSFetchRequest<PersistedEvent>()
        fetchRequest.entity = PersistedEvent.entity()

        var subpredicates = [NSPredicate]()
        subpredicates.append(NSPredicate(format: "%K == %@", #keyPath(PersistedEvent.isProcessed), NSNumber(value: false)))
        subpredicates.append(NSPredicate(format: "%K == %@", #keyPath(PersistedEvent.volumeId), volumeId))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

        return try await managedObjectContext.perform {
            try managedObjectContext.fetch(fetchRequest)
        }
    }
}

extension EventStorageManager {
    public func event(with eventID: EventID) throws -> PersistedEvent? {
        let fetchRequest = NSFetchRequest<PersistedEvent>()
        fetchRequest.entity = PersistedEvent.entity()
        fetchRequest.resultType = .managedObjectResultType
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [.init(key: #keyPath(PersistedEvent.eventEmittedAt), ascending: true)]
        fetchRequest.predicate = .init(format: "%K == %@", #keyPath(PersistedEvent.eventId), eventID)
        fetchRequest.propertiesToFetch = [#keyPath(PersistedEvent.eventEmittedAt)]
        
        var event: PersistedEvent?
        var errorToThrow: Error?
        self.backgroundContext.performAndWait {
            do {
                event = try self.backgroundContext.fetch(fetchRequest).first
            } catch let error {
                errorToThrow = error
            }
        }
        guard errorToThrow == nil else { throw errorToThrow! }
        return event
    }

    public func lastFullyHandledEvent(volumeId: String) throws -> Entry? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult>
        fetchRequest = self.requestEvents(
            excludeIsProcessedEqualTo: false,
            excludeIsEnumeratedEqualTo: false,
            volumeId: volumeId
        )

        return try lastEventBasedOnRequest(fetchRequest)
    }

    public func lastEvent(awaitingEnumerationOnly: Bool, volumeId: String) throws -> Entry? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult>
        if awaitingEnumerationOnly {
            fetchRequest = self.requestEvents(excludeIsProcessedEqualTo: false, excludeIsEnumeratedEqualTo: true, volumeId: volumeId)
        } else {
            fetchRequest = self.requestEvents(volumeId: volumeId)
        }

        return try lastEventBasedOnRequest(fetchRequest)
    }
    
    public func eventsAwaitingEnumeration(since anchorID: EventID?, volumeId: String) throws -> [Entry] {
        var anchorTimestamp: TimeInterval?
        if let anchorID = anchorID {
            guard let event = try self.event(with: anchorID) else {
                return []
            }
            anchorTimestamp = self.backgroundContext.performAndWait {
                event.eventEmittedAt
            }
        }
        
        let fetchRequest = self.requestEvents(since: anchorTimestamp, excludeIsProcessedEqualTo: false, excludeIsEnumeratedEqualTo: true, volumeId: volumeId)
        
        var events: [Entry] = []
        var errorToThrow: Error?
        self.backgroundContext.performAndWait {
            do {
                events = try self.backgroundContext.fetch(fetchRequest) as? [Entry] ?? []
            } catch let error {
                errorToThrow = error
            }
        }
        guard errorToThrow == nil else { throw errorToThrow! }
        return events
    }

    private func lastEventBasedOnRequest(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws -> Entry? {
        fetchRequest.fetchLimit = 1

        fetchRequest.sortDescriptors = [.init(key: #keyPath(PersistedEvent.eventEmittedAt), ascending: false)]

        var event: Entry?
        var errorToThrow: Error?
        self.backgroundContext.performAndWait {
            do {
                event = try self.backgroundContext.fetch(fetchRequest).first as? Entry
            } catch let error {
                errorToThrow = error
            }
        }
        guard errorToThrow == nil else { throw errorToThrow! }
        return event
    }
}
