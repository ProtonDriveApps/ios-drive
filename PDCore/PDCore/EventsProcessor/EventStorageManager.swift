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

// TODO: unify base class with StorageManager after PDFileSystemEvents.framework will be merged with PDCore
public class EventStorageManager: NSObject {
    public typealias Entry = [String: Any]
    public typealias ProviderType = String
    public typealias ShareID = String
    public typealias EventID = String
    
    private static let managedObjectModel: NSManagedObjectModel = {
        guard let bundle = Bundle(for: EventStorageManager.self).url(forResource: "EventStorageModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: bundle) else
        {
            fatalError("Error loading EventStorageModel from bundle")
        }
        return model
    }()
    
    internal static func defaultPersistentContainer(suiteUrl: URL?) -> NSPersistentContainer {
        let databaseName = "EventStorageModel"
        let container = NSPersistentContainer(name: databaseName, managedObjectModel: self.managedObjectModel)
        
        let storeDirectoryUrl = suiteUrl ?? NSPersistentContainer.defaultDirectoryURL()
        let storeFileUrl = storeDirectoryUrl.appendingPathComponent(databaseName + ".sqlite")
        
        let storeDescription = NSPersistentStoreDescription(url: storeFileUrl)
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
    
    internal static func inMemoryPersistantContainer(prePopulatedFrom databaseUrl: URL) -> NSPersistentContainer {
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

    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = self.persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        return context
    }()

    public init(prePopulateFrom template: URL) {
        self.persistentContainer = Self.inMemoryPersistantContainer(prePopulatedFrom: template)
        super.init()
    }
    
    public init(suiteUrl: URL) {
        self.persistentContainer = Self.defaultPersistentContainer(suiteUrl: suiteUrl)
        super.init()
        #if DEBUG
        // swiftlint:disable no_print
        print("💠 EventsCoreData model located at: \(self.persistentContainer.persistentStoreCoordinator.persistentStores)")
        // swiftlint:enable no_print
        #endif
    }
}

extension EventStorageManager {
    public func persist(events: Zip2Sequence<[GenericEvent], [Data]>, provider: ProviderType, shareId: ShareID) {
        self.backgroundContext.performAndWait {
            events.forEach { event, packedOriginal in
                let new = NSEntityDescription.insertNewObject(forEntityName: PersistedEvent.entity().managedObjectClassName, into: self.backgroundContext)
                
                new.setValue(provider, forKey: #keyPath(PersistedEvent.providerType))
                new.setValue(shareId, forKey: #keyPath(PersistedEvent.shareId))
                new.setValue(packedOriginal, forKey: #keyPath(PersistedEvent.contents))
                new.setValue(event.eventId, forKey: #keyPath(PersistedEvent.eventId))
                new.setValue(event.eventEmittedAt, forKey: #keyPath(PersistedEvent.eventEmittedAt))
            }
            
            do {
                try self.backgroundContext.save()
            } catch let error {
                assert(false, error.localizedDescription)
            }
        }
    }
    
    public func discard(_ objectID: NSManagedObjectID) {
        self.backgroundContext.performAndWait {
            let object = self.backgroundContext.object(with: objectID) as? PersistedEvent
            // we need to keep events for EventListeners
            object?.isProcessed = true
            try? self.backgroundContext.save()
        }
    }
    
    public func queue() -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = self.requestEvents(excludeIsProcessedEqualTo: true)
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
                               excluding anchorID: EventID? = nil) -> NSFetchRequest<NSFetchRequestResult>
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
        if let eventID = anchorID {
            subpredicates.append(NSPredicate(format: "%K != %@", #keyPath(PersistedEvent.eventId), eventID))
        }
        if let excluding = excludeIsProcessedEqualTo {
            subpredicates.append(NSPredicate(format: "%K != %@", #keyPath(PersistedEvent.isProcessed), NSNumber(booleanLiteral: excluding)))
        }
        
        let fetchRequest = self.baseRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        return fetchRequest
    }
    
    public func clearUp() {
        self.backgroundContext.performAndWait {
            self.backgroundContext.reset()
            
            [PersistedEvent.self].forEach { entity in
                let request = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity)))
                _ = try? self.persistentContainer.persistentStoreCoordinator.execute(request, with: self.backgroundContext)
            }
        }
    }
    
    public func periodicalCleanup(horizon: DateComponents = .init(day: -10)) throws {
        guard let horizonDate = Calendar.current.date(byAdding: horizon, to: Date()) else {
            return
        }
        let fetchRequest = self.requestEvents(until: horizonDate.timeIntervalSince1970, excludeIsProcessedEqualTo: false)
        fetchRequest.resultType = .managedObjectResultType
        fetchRequest.propertiesToFetch = nil
                
        var errorToThrow: Error?
        self.backgroundContext.performAndWait {
            do {
                try self.backgroundContext.fetch(fetchRequest)
                    .compactMap { $0 as? NSManagedObject }
                    .forEach(self.backgroundContext.delete)
                try self.backgroundContext.save()
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

    public func lastEvent(onlyProcessed: Bool) throws -> Entry? {
        let fetchRequest = self.requestEvents()
        fetchRequest.fetchLimit = 1
        if onlyProcessed {
            fetchRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(PersistedEvent.isProcessed))
        }
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
    
    public func events(since anchorID: EventID?) throws -> [Entry] {
        var anchorTimestamp: TimeInterval? = nil
        if let anchorID = anchorID {
            guard let timestamp = try self.event(with: anchorID)?.eventEmittedAt else {
                return []
            }
            anchorTimestamp = timestamp
        }
        
        let fetchRequest = self.requestEvents(since: anchorTimestamp, excluding: anchorID)
        
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
}
