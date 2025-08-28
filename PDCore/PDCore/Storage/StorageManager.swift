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

// MARK: - Persistent Container Management

public class StorageManager: NSObject, ManagedStorage, RecoverableStorage {
    private static var managedObjectModel: NSManagedObjectModel = {
        return NSManagedObjectModel.makeModel()
    }()
    
    private static let databaseName = "Metadata"

    static var metadataDBWasRecreated = false
    public var previousRunWasInterrupted = false

    internal static func defaultPersistentContainer(suiteUrl: URL?) -> NSPersistentContainer {

        var container = NSPersistentContainer(name: databaseName, managedObjectModel: managedObjectModel)
        
        let storeDirectoryUrl = suiteUrl ?? NSPersistentContainer.defaultDirectoryURL()
        let storeFileUrl = storeDirectoryUrl.appendingPathComponent(databaseName + ".sqlite")
        
        do {
            try MigrationDetector().checkIfRequiresPostMigrationCleanup(storeAt: storeFileUrl, for: managedObjectModel)
        } catch { 
            Log.error("Migration requirement check failed", error: error, domain: .storage)
        }
        
        let storeDescription = NSPersistentStoreDescription(url: storeFileUrl)
        storeDescription.shouldMigrateStoreAutomatically = true // Lightweight migration is enabled. Standard migrations from previous versions are to be handled below.
        storeDescription.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [storeDescription]

        // If the file doesn't exist, a new one will be created.
        // We need to know it was newly created, so that we populate it later.
        Self.metadataDBWasRecreated = !FileManager.default.fileExists(atPath: storeFileUrl.path)

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

        if let loadError = loadError as NSError? {
            let hashDigest = (try? MigrationDetector().hashDigest(storeAt: storeFileUrl)) ?? "UNREADABLE"
            Log
                .error(
                    "Persistent coordinator creation failed",
                    error: loadError, domain: .storage,
                    context: LogContext("Hash digest on disk: \(hashDigest)")
                )

            switch loadError.code {
            case NSInferredMappingModelError,
                NSMigrationMissingMappingModelError, // Lightweight migration not possible.
                NSPersistentStoreIncompatibleVersionHashError,
                NSPersistentStoreIncompatibleSchemaError,
                11, // The operation couldn’t be completed. (NSSQLiteErrorDomain error 11.) (DB with 3 tables)
                259: // / The file “Metadata.sqlite” couldn’t be opened because it isn’t in the correct format

                // Delete any stored files, as their references will be lost with the persistent store being reset
                // Delete `Metadata.sqlite`
                deleteSQLite(storeDirectoryUrl: storeDirectoryUrl)
                PDFileManager.destroyPermanents()
                PDFileManager.destroyCaches()

                // Recreate directories
                PDFileManager.initializeIntermediateFolders()
                    
                container = StorageManager.defaultPersistentContainer(suiteUrl: suiteUrl)

                Self.metadataDBWasRecreated = true
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
    
    private static func deleteSQLite(storeDirectoryUrl: URL, databaseName: String = databaseName) {
        let exts = ["sqlite", "sqlite-shm", "sqlite-wal"]
        var destroyErrors: [Error] = []
        for ext in exts {
            let storeFileUrl = storeDirectoryUrl.appendingPathComponent("\(databaseName).\(ext)")
            do {
                try FileManager.default.removeItem(at: storeFileUrl)
            } catch {
                if (error as NSError).code != 4 /* No such file or directory */ {
                    destroyErrors.append(error)
                }
            }
        }
        if !destroyErrors.isEmpty {
            let description = destroyErrors.map(\.localizedDescription).joined(separator: ", ")
            Log.error("Persistent coordinator destroying failed", domain: .storage, context: LogContext(description))
            fatalError("Failed to destroy persistent store: \(destroyErrors[0])")
        }
    }

    // Tests only
    public static func inMemoryPersistantContainer() -> NSPersistentContainer {
        let managedObjectModel = NSManagedObjectModel.makeModel()
        if managedObjectModel.versionIdentifiers != self.managedObjectModel.versionIdentifiers {
            // Force fresh creation of model to account for variable context in tests (different models in different test cases)
            // Otherwise keep using the same cached model, because reinitializing the model leads to entity ambiguity and crashes:
            // `CoreData: warning: Multiple NSEntityDescriptions claim the NSManagedObject subclass '[Volume/File/etc]' so +entity is unable to disambiguate`
            self.managedObjectModel = managedObjectModel
        }
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
    
    @available(*, deprecated, message: "Remove when the old implementation of Public Link is removed")
    @SettingsStorage("finishedFetchingShareURLs") var finishedFetchingShareURLs: Bool?

    @SettingsStorage("finishedFetchingSharedByMe") public var finishedFetchingSharedByMe: Bool?
    @SettingsStorage("finishedFetchingSharedWithMe") public var finishedFetchingSharedWithMe: Bool?
    @SettingsStorage("finishedFetchingTrash") var finishedFetchingTrash: Bool?
    private let persistentContainer: NSPersistentContainer
    let userDefaults: UserDefaults // Ideally, this should be replaced with @SettingsStorage
    
    private static let recoveryDatabaseName = "Recovery_\(databaseName)"
    private static let backupDatabaseName = "Backup_\(databaseName)"
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

    public convenience init(suite: SettingsStorageSuite, sessionVault: SessionVault) {
        switch suite {
        case let .inMemory(dataUrl):
            self.init(container: Self.inMemoryPersistantContainer(prePopulatedFrom: dataUrl), userDefaults: suite.userDefaults)
        default:
            self.init(container: Self.defaultPersistentContainer(suiteUrl: suite.directoryUrl), userDefaults: suite.userDefaults)
        }
        
        self._finishedFetchingShareURLs.configure(with: suite)
        self._finishedFetchingSharedByMe.configure(with: suite)
        self._finishedFetchingSharedWithMe.configure(with: suite)
        self._finishedFetchingTrash.configure(with: suite)
    }

    /// Tests only (otherwise should be private)!
    public init(container: NSPersistentContainer, userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        self.persistentContainer = container
        self.persistentContainer.observeCrossProcessDataChanges()

        super.init()
        
        do {
            try restoreFromBackup()
            self.previousRunWasInterrupted = cleanupLeftoversFromPreviousRecoveryAttempt()
        } catch {
            Log.error("Restoring from backup failed", error: error, domain: .storage)
        }
        
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(notifyOtherProcessesOfContextSaving), name: .NSManagedObjectContextDidSave, object: self.mainContext)
        center.addObserver(self, selector: #selector(notifyOtherProcessesOfContextSaving), name: .NSManagedObjectContextDidSave, object: self.backgroundContext)
        
        #if DEBUG
        Log.debug(
                "💠 CoreData model located at: \(self.persistentContainer.persistentStoreCoordinator.persistentStores)",
                domain: .storage
            )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func notifyOtherProcessesOfContextSaving() {
        #if os(iOS)
        DarwinNotificationCenter.shared.postNotification(.DidSaveManagedObjectContextLocally)
        #endif
        
        userDefaults.set(Date().timeIntervalSince1970, forKey: UserDefaults.NotificationPropertyKeys.metadataDBUpdateKey.rawValue)
        userDefaults.synchronize() // ensures property change will be observed in other processes
    }
    
    public func prepareForTermination() {
        self.mainContext.performAndWait {
            try? self.mainContext.saveOrRollback()
        }
        
        // remove everything per entity
        self.backgroundContext.performAndWait {
            try? self.backgroundContext.saveOrRollback()
        }
    }

    public lazy var mainContext: NSManagedObjectContext = {
        #if os(macOS)
        if Constants.runningInExtension {
            return newBackgroundContext()
        } else {
            let context = self.persistentContainer.viewContext
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
            Self.keepWeakReferenceToContext(context, in: contexts)
            return context
        }
        #else
        let context = self.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        Self.keepWeakReferenceToContext(context, in: contexts)
        return context
        #endif
    }()
    
    public lazy var backgroundContext: NSManagedObjectContext = {
        let context = self.persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        Self.keepWeakReferenceToContext(context, in: contexts)
        return context
    }()

    public lazy var photosBackgroundContext: NSManagedObjectContext = {
        newBackgroundContext()
    }()

    public lazy var photosSecondaryBackgroundContext: NSManagedObjectContext = {
        newBackgroundContext()
    }()

    public lazy var eventsBackgroundContext: NSManagedObjectContext = {
        newBackgroundContext()
    }()

    public func newBackgroundContext(mergePolicy: NSMergePolicy = .mergeByPropertyStoreTrump) -> NSManagedObjectContext {
        let context = self.persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = mergePolicy
        Self.keepWeakReferenceToContext(context, in: contexts)
        return context
    }

    func privateChildContext(of parent: NSManagedObjectContext) -> NSManagedObjectContext {
        let child = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        child.parent = parent
        child.automaticallyMergesChangesFromParent = true
        child.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        Self.keepWeakReferenceToContext(child, in: contexts)
        return child
    }
    
    public func cleanUp() async {
        finishedFetchingTrash = nil
        finishedFetchingSharedByMe = nil
        finishedFetchingSharedWithMe = nil
        finishedFetchingShareURLs = nil

        userDefaults.removeObject(forKey: UserDefaults.NotificationPropertyKeys.metadataDBUpdateKey.rawValue)

        await self.mainContext.perform {
            self.mainContext.reset()
        }

        // remove everything per entity
        await self.backgroundContext.perform {
            self.backgroundContext.reset()
            
            let hasInMemoryStore = self.persistentContainer.persistentStoreCoordinator.persistentStores.contains { store in
                store.type == NSPersistentStore.StoreType.inMemory.rawValue
            }
            
            // in memory stores do not support the NSBatchDeleteRequest
            if hasInMemoryStore {
                [Node.self, Block.self, Revision.self, Volume.self, Share.self, Thumbnail.self, ShareURL.self, Photo.self, Device.self, PhotoRevision.self, ThumbnailBlob.self, Invitation.self, CoreDataAlbum.self, CoreDataAlbumListing.self, CoreDataPhotoListing.self].forEach { entity in
                    let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: entity))
                    do {
                        let result = try self.backgroundContext.fetch(request)
                        result.forEach { self.backgroundContext.delete($0) }
                        try self.backgroundContext.save()
                    } catch {
                        assert(false, "Could not perform one-by-one deletion after logout")
                    }
                }
            } else {
                [CoreDataPhotoListing.self, CoreDataAlbumListing.self, Node.self, Block.self, Revision.self, Volume.self, Share.self, Thumbnail.self, ShareURL.self, Photo.self, Device.self, PhotoRevision.self, ThumbnailBlob.self, Invitation.self, CoreDataAlbum.self].forEach { entity in
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity))
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    deleteRequest.resultType = .resultTypeObjectIDs
                    do {
                        if let result = try self.persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: self.backgroundContext) as? NSBatchDeleteResult,
                           let objectIDs = result.result as? [NSManagedObjectID] {
                            let changes: [String: Any] = [NSDeletedObjectsKey: objectIDs]
                            let activeContexts = self.contexts.value.compactMap { $0.reference }
                            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: activeContexts)
                        }
                    } catch {
                        Log.error("Storage deletion error", error: error, domain: .storage)
                        // fallback for batch deletion not working
                        do {
                            fetchRequest.resultType = .managedObjectResultType
                            let results = try self.backgroundContext.fetch(fetchRequest)
                            guard let objectsForDeletion = results as? [NSManagedObject] else {
                                assert(false, "Could not perform batch deletion after logout")
                                return
                            }
                            for object in objectsForDeletion {
                                self.backgroundContext.delete(object)
                            }
                            try self.backgroundContext.save()
                        } catch {
                            assert(false, "Could not perform batch deletion after logout")
                        }
                    }
                }
            }
        }
    }

    public func moveToMainContext<T: NSManagedObject>(_ object: T) -> T {
        return mainContext.object(with: object.objectID) as! T
    }
}
