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

public enum SyncItemError: Error {
    case notFound
}

public final class SyncStorageManager: NSObject, ManagedStorage {

    private static let databaseName = "SyncModel"
    
    private static let managedObjectModel: NSManagedObjectModel = {
        if let bundle = Bundle(for: SyncStorageManager.self).url(forResource: databaseName, withExtension: "momd"),
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

        fatalError("Error loading SyncModel from bundle")
    }()
    
    private static func defaultPersistentContainer(suiteUrl: URL?) -> NSPersistentContainer {
        var container = NSPersistentContainer(name: databaseName, managedObjectModel: self.managedObjectModel)

        let storeDirectoryUrl = suiteUrl ?? NSPersistentContainer.defaultDirectoryURL()
        let storeFileUrl = storeDirectoryUrl.appendingPathComponent(databaseName + ".sqlite")

        let storeDescription = NSPersistentStoreDescription(url: storeFileUrl)

        let persistentHistoryTrackingValue = true // set to false to disable history tracking and remove previous history store

        storeDescription.setOption(persistentHistoryTrackingValue as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(persistentHistoryTrackingValue as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription.shouldMigrateStoreAutomatically = true // Lightweight migration is enabled. Standard migrations from previous versions are to be handled below.
        storeDescription.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [storeDescription]

        // Completion handler is @escaping, but we do not feel that because it is executed synchronously by some reason
        // Possibility of race condition (ノಠ益ಠ)ノ彡┻━┻
        var loadError: Error?
        container.loadPersistentStores { (description, error) in
            loadError = error

            do {
                try FileManager.default.secureFilesystemItems(storeFileUrl)
            } catch {
                assertionFailure(error.localizedDescription)
            }
        }

        configurePersistentHistoryTrackingAndReloadStores(value: persistentHistoryTrackingValue, storeFileUrl: storeFileUrl, container: container, storeDescription: storeDescription) { error in
            if let error {
                loadError = error
            }
        }

        if let loadError = loadError as NSError? {
            switch loadError.code {
            case NSInferredMappingModelError, NSMigrationMissingMappingModelError: // Lightweight migration not possible.
                fallthrough
            case NSPersistentStoreIncompatibleVersionHashError:
                do {
                    // Delete any stored files, as their references will be lost with the persistent store being reset
                    try container.persistentStoreCoordinator.destroyPersistentStore(at: storeFileUrl, ofType: NSSQLiteStoreType, options: nil)
                    PDFileManager.destroyPermanents()
                    PDFileManager.destroyCaches()

                    // Recreate directories
                    PDFileManager.initializeIntermediateFolders()

                    container = StorageManager.defaultPersistentContainer(suiteUrl: suiteUrl)
                } catch {
                    fatalError("Failed to destroy persistent store: \(error)")
                }
            default:
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(loadError), \(loadError.userInfo)")
            }
        }

        return container
    }

    private static func configurePersistentHistoryTrackingAndReloadStores(
        value: Bool, storeFileUrl: URL, container: NSPersistentContainer,
        storeDescription: NSPersistentStoreDescription, completionHandler: @escaping (Error?) -> Void) {
        do {
            var storeMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeFileUrl)
            if let persistentStore = container.persistentStoreCoordinator.persistentStore(for: storeFileUrl) {
                let persistentHistoryTrackingKeyPreviouslyEnabled = storeMetadata["NSPersistentHistoryTrackingKeyEnabled"] as? Bool
                if value == false && (persistentHistoryTrackingKeyPreviouslyEnabled ?? false) {
                    storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                    container.persistentStoreDescriptions = [storeDescription]

                    try container.persistentStoreCoordinator.remove(persistentStore)
                    reloadPersistentStores(container: container, storeFileUrl: storeFileUrl, completion: completionHandler)

                    let context = container.viewContext
                    context.automaticallyMergesChangesFromParent = true
                    context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
                    clearPersistentHistory(context: context)

                    storeDescription.setOption(value as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                    container.persistentStoreDescriptions = [storeDescription]

                    if let store = container.persistentStoreCoordinator.persistentStore(for: storeFileUrl) {
                        try container.persistentStoreCoordinator.remove(store)
                        reloadPersistentStores(container: container, storeFileUrl: storeFileUrl, completion: completionHandler)
                    }

                }

                persistentStore.isReadOnly = false

                storeMetadata["NSPersistentHistoryTrackingKeyEnabled"] = value
                persistentStore.metadata = storeMetadata
            }
        } catch {
            Log.error("Error on setting persistent history tracking: \(error.localizedDescription)", domain: .storage)
            completionHandler(error)
        }
    }

    private static func reloadPersistentStores(container: NSPersistentContainer, storeFileUrl: URL, completion: @escaping (Error?) -> Void) {
        container.loadPersistentStores { _, error in
            if let error = error {
                completion(error)
                return
            }
            do {
                try FileManager.default.secureFilesystemItems(storeFileUrl)
            } catch {
                completion(error)
            }
        }
    }

    private static func clearPersistentHistory(context: NSManagedObjectContext) {
        context.performAndWait {
            let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: .distantFuture)
            do {
                _ = try context.execute(deleteHistoryRequest)
                Log.debug("deleteHistoryRequest executed", domain: .storage)
            } catch {
                Log.debug("deleteHistoryRequest failed to execute: \(error.localizedDescription)", domain: .storage)
            }
        }
    }

    static func inMemoryPersistantContainer() -> NSPersistentContainer {
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

    let persistentContainer: NSPersistentContainer

    public lazy var mainContext: NSManagedObjectContext = {
        if Constants.runningInExtension {
            return backgroundContext
        } else {
            let context = self.persistentContainer.viewContext
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
            return context
        }
    }()

    public lazy var backgroundContext: NSManagedObjectContext = {
        let context = self.persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        return context
    }()

    public init(suite: SettingsStorageSuite) {
        #if os(macOS)
        switch suite {
        case .inMemory:
            self.persistentContainer = Self.inMemoryPersistantContainer()
        default:
            self.persistentContainer = Self.defaultPersistentContainer(suiteUrl: suite.directoryUrl)
        }
        #else
        self.persistentContainer = Self.inMemoryPersistantContainer()
        #endif

        #if DEBUG
        Log.debug("💠 Sync CoreData model located at: \(self.persistentContainer.persistentStoreCoordinator.persistentStores)", domain: .storage)
        #endif
    }

    public func clearUp() async {
        await self.mainContext.perform {
            self.mainContext.reset()
        }

        await self.backgroundContext.perform {
            self.backgroundContext.reset()

            [SyncItem.self].forEach { entity in
                let request = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity)))
                request.resultType = .resultTypeObjectIDs
                do {
                    _ = try self.persistentContainer.persistentStoreCoordinator.execute(request, with: self.backgroundContext)
                } catch {
                    assert(false, "Could not perform batch deletion after logout")
                }
            }
        }
    }

}
