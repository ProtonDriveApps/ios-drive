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

import SQLite3
import CoreData
import ProtonCoreUtilities

public protocol RecoverableStorage: AnyObject {
    func disconnectExistingDB() throws -> PersistentStoreInfo
    func createRecoveryDB(nextTo backup: PersistentStoreInfo) throws -> PersistentStoreInfo
    func reconnectExistingDBAndDiscardRecoveryIfNeeded(existing: PersistentStoreInfo, recovery: PersistentStoreInfo?) throws
    func replaceExistingDBWithRecovery(existing: PersistentStoreInfo, recovery: PersistentStoreInfo) throws
    @discardableResult func cleanupLeftoversFromPreviousRecoveryAttempt() -> Bool
    func moveExistingDBToBackup(existing: PersistentStoreInfo) throws -> PersistentStoreInfo
    func restoreFromBackup() throws
    var previousRunWasInterrupted: Bool { get }
}

public enum BackupAndRestoreDBErrors: LocalizedError {
    case noStore
    case noStoreURL
    case noStoreDescription
    case storeAdditionFailed(innerError: Error)
    case storeLoadingFailed(innerError: Error)
    case storeMigrationFailed(innerError: Error)
    case storeReplacingFailed(innerError: Error)
    case storeRemovalFailed(innerError: Error)
    case storeDeletionFailed(innerError: Error)
    
    public var errorDescription: String? {
        switch self {
        case .noStore: return "No store found"
        case .noStoreURL: return "No store URL found"
        case .noStoreDescription: return "No store description found"
        case .storeAdditionFailed(let innerError): return "Store addition failed: \(innerError.localizedDescription)"
        case .storeLoadingFailed(let innerError): return "Store loading failed: \(innerError.localizedDescription)"
        case .storeMigrationFailed(let innerError): return "Store migration failed: \(innerError.localizedDescription)"
        case .storeReplacingFailed(let innerError): return "Store replacing failed: \(innerError.localizedDescription)"
        case .storeRemovalFailed(let innerError): return "Store removal failed: \(innerError.localizedDescription)"
        case .storeDeletionFailed(let innerError): return "Store deletion failed: \(innerError.localizedDescription)"
        }
    }
}

public struct PersistentStoreInfo {
    let name: String
    let store: NSPersistentStore
    let type: NSPersistentStore.StoreType
    let description: NSPersistentStoreDescription
    let url: URL
}

// Covers the subset of NSPersistentContainer API used in recovery methods. Introduced for mocking in tests
public protocol PersistentContainerProtocol: AnyObject {
    var storeCoordinator: PersistentStoreCoordinatorProtocol { get }
    var storeDescriptions: [NSPersistentStoreDescription] { get set }
    func loadPersistentStores(completionHandler: @escaping (NSPersistentStoreDescription, (any Error)?) -> Void)
}

extension NSPersistentContainer: PersistentContainerProtocol {
    public var storeCoordinator: any PersistentStoreCoordinatorProtocol { persistentStoreCoordinator }
    public var storeDescriptions: [NSPersistentStoreDescription] {
        get { persistentStoreDescriptions }
        set { persistentStoreDescriptions = newValue }
    }
}

// Covers the subset of NSPersistentStoreCoordinator API used in recovery methods. Introduced for mocking in tests
public protocol PersistentStoreCoordinatorProtocol: AnyObject {
    var persistentStores: [NSPersistentStore] { get }
    func addPersistentStore(type: NSPersistentStore.StoreType, configuration: String?, at storeURL: URL, options: [AnyHashable: Any]?) throws -> NSPersistentStore
    func migratePersistentStore(_ store: NSPersistentStore, to storeURL: URL, options: [AnyHashable: Any]?, type storeType: NSPersistentStore.StoreType) throws -> NSPersistentStore
    func replacePersistentStore(at destinationURL: URL, destinationOptions: [AnyHashable: Any]?, withPersistentStoreFrom sourceURL: URL, sourceOptions: [AnyHashable: Any]?, type sourceType: NSPersistentStore.StoreType) throws
    func remove(_ store: NSPersistentStore) throws
    func destroyPersistentStore(at url: URL, type storeType: NSPersistentStore.StoreType, options: [AnyHashable: Any]?) throws
}

extension NSPersistentStoreCoordinator: PersistentStoreCoordinatorProtocol {}

extension RecoverableStorage {
    
    public static func disconnectExistingDB(
        named: String,
        using persistentContainer: PersistentContainerProtocol,
        contexts: Atomic<[WeakReference<NSManagedObjectContext>]>
    ) throws -> PersistentStoreInfo {
        let (existingStore, descriptionIndex) = try identifyExistingDB(named: named, using: persistentContainer)
        do {
            try persistentContainer.storeCoordinator.remove(existingStore.store)
            persistentContainer.storeDescriptions.remove(at: descriptionIndex)
        } catch {
            throw BackupAndRestoreDBErrors.storeRemovalFailed(innerError: error)
        }
        resetAllContexts(contexts)
        return existingStore
    }
    
    public static func createRecoveryDB(
        named: String,
        nextTo existing: PersistentStoreInfo,
        using persistentContainer: PersistentContainerProtocol
    ) throws -> PersistentStoreInfo {
        let recoveryStoreURL = storeURL(named: named, nextTo: existing)
        let persistentStoreDescription = NSPersistentStoreDescription(url: recoveryStoreURL)
        persistentContainer.storeDescriptions.append(persistentStoreDescription)
        var loadError: Error?
        persistentContainer.loadPersistentStores { description, error in
            loadError = error
        }
        if let loadError {
            throw BackupAndRestoreDBErrors.storeLoadingFailed(innerError: loadError)
        }
        guard let recoveryStore = persistentContainer.storeCoordinator.persistentStores.first(where: { $0.url == recoveryStoreURL }) else {
            throw BackupAndRestoreDBErrors.noStore
        }
        return PersistentStoreInfo(
            name: named,
            store: recoveryStore,
            type: NSPersistentStore.StoreType(rawValue: recoveryStore.type),
            description: persistentStoreDescription,
            url: recoveryStoreURL
        )
    }
    
    public static func reconnectExistingDBAndDiscardRecoveryIfNeeded(
        existing: PersistentStoreInfo,
        recovery: PersistentStoreInfo?,
        using persistentContainer: PersistentContainerProtocol,
        contexts: Atomic<[WeakReference<NSManagedObjectContext>]>
    ) throws {
        resetAllContexts(contexts)

        // 1. Remove recovery if needed
        if let recovery {
            try remove(store: recovery.store, from: persistentContainer)
        }

        // 2. Bring back existing
        _ = try addStore(at: existing.url, type: existing.type, description: existing.description, using: persistentContainer)

        // 3. Delete recovery if needed
        if let recovery {
            try delete(store: recovery, using: persistentContainer)
        }
    }
    
    public static func replaceExistingDBWithRecovery(
        backupName: String,
        existing: PersistentStoreInfo,
        recovery: PersistentStoreInfo,
        using persistentContainer: PersistentContainerProtocol,
        contexts: Atomic<[WeakReference<NSManagedObjectContext>]>
    ) throws {
        let backup = try moveExistingDBToBackup(backupName: backupName, existing: existing, using: persistentContainer, contexts: contexts)
        try makeRecoveryDBTheMainDB(recovery: recovery, existing: existing, backup: backup, using: persistentContainer)
        try delete(store: backup, using: persistentContainer)
    }
    
    public static func cleanupLeftoversFromPreviousRecoveryAttempt(
        existingName: String,
        recoveryName: String,
        backupName: String,
        using persistentContainer: PersistentContainerProtocol) -> Bool {
        do {
            let existing: PersistentStoreInfo = try identifyExistingDB(named: existingName, using: persistentContainer).0
            var fileExistedBefore = false
            do {
                fileExistedBefore = try deleteAndRemoveIfNeeded(name: recoveryName, existing: existing, persistentContainer: persistentContainer)
            } catch {
                Log.info("Leftovers from previous recovery cleanup failed for \(recoveryName): \(error.localizedDescription)", domain: .storage)
            }
            do {
                _ = try deleteAndRemoveIfNeeded(name: backupName, existing: existing, persistentContainer: persistentContainer)
            } catch {
                Log.info("Leftovers from previous recovery cleanup failed for \(backupName): \(error.localizedDescription)", domain: .storage)
            }
            return fileExistedBefore
        } catch {
            Log.info("No existing database found to cleanup leftovers from previous recovery attempt for: \(error.localizedDescription)",
                     domain: .storage)
            return false
        }
    }
    
    public static func moveExistingDBToBackup(
        backupName: String,
        existing: PersistentStoreInfo,
        using persistentContainer: PersistentContainerProtocol,
        contexts: Atomic<[WeakReference<NSManagedObjectContext>]>
    ) throws -> PersistentStoreInfo {
        resetAllContexts(contexts)
        do {
            try persistentContainer.storeCoordinator.persistentStores.forEach {
                try persistentContainer.storeCoordinator.remove($0)
            }
            persistentContainer.storeDescriptions.removeAll()
        } catch {
            throw BackupAndRestoreDBErrors.storeRemovalFailed(innerError: error)
        }
        
        let existingStore: NSPersistentStore
        do {
            existingStore = try persistentContainer.storeCoordinator
                .addPersistentStore(type: existing.type, configuration: nil, at: existing.url, options: nil)
        } catch {
            throw BackupAndRestoreDBErrors.storeAdditionFailed(innerError: error)
        }
        let backupURL = storeURL(named: backupName, nextTo: existing)
        
        let backupStore: NSPersistentStore
        do {
            backupStore = try persistentContainer.storeCoordinator.migratePersistentStore(
                existingStore, to: backupURL, options: nil, type: existing.type
            )
        } catch {
            throw BackupAndRestoreDBErrors.storeMigrationFailed(innerError: error)
        }
        do {
            try persistentContainer.storeCoordinator.remove(backupStore)
        } catch {
            throw BackupAndRestoreDBErrors.storeRemovalFailed(innerError: error)
        }
        
        return PersistentStoreInfo(
            name: backupName,
            store: backupStore,
            type: existing.type,
            description: NSPersistentStoreDescription(url: backupURL),
            url: backupURL
        )
    }
    
    public static func restoreFromBackup(backupName: String, existingName: String, using persistentContainer: PersistentContainerProtocol) throws {
        guard let (existing, _) = try? identifyExistingDB(named: existingName, using: persistentContainer) else {
            return // if there's no existing store, there's nothing to replace
        }
        let backupURL = storeURL(named: backupName, nextTo: existing)
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return // if there's no backup store, there's nothing to replace with
        }
        do {
            try replaceStore(at: existing.url, with: backupURL, type: existing.type, using: persistentContainer)
        } catch BackupAndRestoreDBErrors.storeReplacingFailed(let innerError as NSError) {
            if innerError.domain == NSSQLiteErrorDomain,
               // these errors indicate there's either no file at backupURL (even though FileManager.fileExists tells otherwise)
               // or that the file cannot be used becaused it's not a DB or it's corrupted — either way, useless
               [SQLITE_CANTOPEN, SQLITE_CORRUPT, SQLITE_NOTADB].contains(Int32(innerError.code)) {
                // if the file cannot be used, remove it if possible so that it won't show up next time
                try? delete(storeURL: backupURL, storeType: existing.type, storeName: backupName, using: persistentContainer)
                return
            } else {
                throw BackupAndRestoreDBErrors.storeReplacingFailed(innerError: innerError)
            }
        }
        _ = try addStore(at: existing.url, type: existing.type, description: existing.description, using: persistentContainer)
        try? delete(storeURL: backupURL, storeType: existing.type, storeName: backupName, using: persistentContainer)
    }
    
    static func keepWeakReferenceToContext(_ context: NSManagedObjectContext, in contexts: Atomic<[WeakReference<NSManagedObjectContext>]>) {
        contexts.mutate { value in
            value.append(WeakReference(reference: context))
        }
    }
    
    private static func identifyExistingDB(
        named: String, using persistentContainer: PersistentContainerProtocol
    ) throws -> (PersistentStoreInfo, Int) {
        guard let existingStore = persistentContainer.storeCoordinator.persistentStores.first else {
            throw BackupAndRestoreDBErrors.noStore
        }
        guard let existingStoreURL = existingStore.url else {
            throw BackupAndRestoreDBErrors.noStoreURL
        }
        guard let descriptionIndex = persistentContainer.storeDescriptions.firstIndex(where: { $0.url == existingStoreURL }) else {
            throw BackupAndRestoreDBErrors.noStoreDescription
        }
        let persistentStoreDescription = persistentContainer.storeDescriptions[descriptionIndex]
        let info = PersistentStoreInfo(
            name: named,
            store: existingStore,
            type: NSPersistentStore.StoreType(rawValue: existingStore.type),
            description: persistentStoreDescription,
            url: existingStoreURL
        )
        return (info, descriptionIndex)
    }
    
    private static func storeURL(named: String, nextTo existing: PersistentStoreInfo) -> URL {
        existing.url.deletingLastPathComponent().appendingPathComponent(named + ".sqlite")
    }
    
    private static func resetAllContexts(_ contexts: Atomic<[WeakReference<NSManagedObjectContext>]>) {
        contexts.mutate {
            $0 = $0.filter { $0.reference != nil }
        }
        contexts.value.forEach { context in
            context.reference?.performAndWait {
                context.reference?.reset()
            }
        }
    }
    
    private static func makeRecoveryDBTheMainDB(
        recovery: PersistentStoreInfo, existing: PersistentStoreInfo, backup: PersistentStoreInfo, using persistentContainer: PersistentContainerProtocol
    ) throws {
        let usedType: NSPersistentStore.StoreType
        do {
            try replaceStore(at: existing.url, with: recovery.url, type: recovery.type, using: persistentContainer)
            usedType = recovery.type
        } catch {
            try replaceStore(at: existing.url, with: backup.url, type: backup.type, using: persistentContainer)
            usedType = backup.type
        }
        _ = try addStore(at: existing.url, type: usedType, description: existing.description, using: persistentContainer)
        try delete(store: recovery, using: persistentContainer)
    }
    
    private static func addStore(
        at url: URL,
        type: NSPersistentStore.StoreType,
        description: NSPersistentStoreDescription,
        using persistentContainer: any PersistentContainerProtocol
    ) throws -> NSPersistentStore {
        do {
            let store = try persistentContainer.storeCoordinator.addPersistentStore(
                type: type, configuration: nil, at: url, options: nil
            )
            persistentContainer.storeDescriptions.append(description)
            return store
        } catch {
            throw BackupAndRestoreDBErrors.storeAdditionFailed(innerError: error)
        }
    }
    
    private static func replaceStore(
        at atURL: URL,
        with withURL: URL,
        type: NSPersistentStore.StoreType,
        using persistentContainer: PersistentContainerProtocol
    ) throws {
        do {
            try persistentContainer.storeCoordinator.replacePersistentStore(
                at: atURL,
                destinationOptions: nil,
                withPersistentStoreFrom: withURL,
                sourceOptions: nil,
                type: type
            )
        } catch {
            throw BackupAndRestoreDBErrors.storeReplacingFailed(innerError: error)
        }
    }
    
    private static func remove(store: NSPersistentStore, from persistentContainer: any PersistentContainerProtocol) throws {
        do {
            try persistentContainer.storeCoordinator.remove(store)
        } catch {
            throw BackupAndRestoreDBErrors.storeRemovalFailed(innerError: error)
        }
        persistentContainer.storeDescriptions.removeAll { $0.url == store.url }
    }
    
    private static func deleteAndRemoveIfNeeded(
        name: String,
        existing: PersistentStoreInfo,
        persistentContainer: any PersistentContainerProtocol) throws -> Bool {
        let url = storeURL(named: name, nextTo: existing)

        let fileExistedBefore = FileManager.default.fileExists(atPath: url.path)
        if let store = persistentContainer.storeCoordinator.persistentStores.first(where: { $0.url == url }) {
            try remove(store: store, from: persistentContainer)
        }
        if let descriptionIndex = persistentContainer.storeDescriptions.firstIndex(where: { $0.url == url }) {
            persistentContainer.storeDescriptions.remove(at: descriptionIndex)
        }
        try delete(storeURL: url, storeType: existing.type, storeName: name, using: persistentContainer)

        return fileExistedBefore
    }
    
    private static func delete(store: PersistentStoreInfo, using persistentContainer: PersistentContainerProtocol) throws {
        try delete(storeURL: store.url, storeType: store.type, storeName: store.name, using: persistentContainer)
    }
    
    private static func delete(
        storeURL: URL,
        storeType: NSPersistentStore.StoreType,
        storeName: String,
        using persistentContainer: PersistentContainerProtocol
    ) throws {
        do {
            try persistentContainer.storeCoordinator.destroyPersistentStore(
                at: storeURL, type: storeType, options: [NSPersistentStoreForceDestroyOption: true]
            )
            try FileManager.default
                .contentsOfDirectory(at: storeURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)
                .filter { url in
                    url.deletingPathExtension().lastPathComponent == storeName
                }
                .forEach {
                    try FileManager.default.removeItem(at: $0)
                }
        } catch {
            throw BackupAndRestoreDBErrors.storeDeletionFailed(innerError: error)
        }
    }
}
