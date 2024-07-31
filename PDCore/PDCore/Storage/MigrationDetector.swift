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

public final class MigrationDetector {
    @SettingsStorage("requiresPostMigrationStep") private var requiresPostMigrationCleanup: Bool?
    
    public init() {
        self._requiresPostMigrationCleanup.configure(with: .group(named: Constants.appGroup))
    }
    
    internal func checkIfRequiresPostMigrationCleanup(storeAt storeFileUrl: URL, for model: NSManagedObjectModel) throws {
        guard requiresPostMigrationCleanup != true else { return }
        requiresPostMigrationCleanup = try coreDataWillInvokeMigration(storeAt: storeFileUrl, for: model)
            && requiresPostMigrationStep(storeAt: storeFileUrl)
    }
    
    public var requiresPostMigrationStep: Bool {
        requiresPostMigrationCleanup == true
    }
    
    public func postMigrationCleanupIsComplete() {
        requiresPostMigrationCleanup = nil
    }
    
    // Do we really need this if we can analyse store directly?
    private func coreDataWillInvokeMigration(storeAt storeFileUrl: URL, for model: NSManagedObjectModel) throws -> Bool {
        guard FileManager.default.fileExists(atPath: storeFileUrl.path) else {
            Log.info("CoreData DB file not found", domain: .storage)
            return false
        }
        
        let storeMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeFileUrl)
        let requiresMigration = !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: storeMetadata)
        
        if requiresMigration {
            Log.info("CoreData will invoke migration to a new model", domain: .storage)
        } else {
            Log.info("CoreData does not need migration to a new model", domain: .storage)
        }
        
        return requiresMigration
    }
    
    // Look at hashes of existing store
    private func requiresPostMigrationStep(storeAt storeFileUrl: URL) throws -> Bool {
        /*
         Rather than enumerating through all the relevant parts of a model, Core Data creates a 32-byte hash digest of the components which it compares for equality (see `versionHash(NSEntityDescription)` and `versionHash(NSPropertyDescription)`). These hashes are included in a store’s metadata so that Core Data can quickly determine whether the store format matches that of the managed object model it may use to try to open the store. (When you attempt to open a store using a given model, Core Data compares the version hashes of each of the entities in the store with those of the entities in the model, and if all are the same then the store is opened.) There is typically no reason for you to be interested in the value of a hash.
         
         https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/vmUnderstandingVersions.html
         
         Option A: list all entity hashes of already released versions (1.1x -> 1.24) that require post-migration cleanup
         Option B: list all hashes of already released versions (1.1x -> 1.24) that require post-migration cleanup
         
         Here we apply option B.
         
         In order to collect a hash, put a breakpoint in `StorageManager.defaultPersistentContainer(suiteUrl: URL?)` and run this command:
         > po (try! NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeFileUrl))["NSStoreModelVersionHashesDigest"]
         
         */
        
        guard let hashDigest = try hashDigest(storeAt: storeFileUrl) else {
            // no hash digest on disk - no evidence that migration is needed
            return false
        }
        
        return [
            "C0/taEnzjxuUUQkw95ILN0nxvOeYQ3PeYv05Et2RdSMEEKTMp1hdCwdsszSAUb4NjV4MUbxKEZ7XZzWwWODpcg==", // Metadata v1.24 | develop 9d7923371
            "C0/taEnzjxuUUQkw95ILN0nxvOeYQ3PeYv05Et2RdSMEEKTMp1hdCwdsszSAUb4NjV4MUbxKEZ7XZzWwWODpcg==", // Metadata v1.24 | mac/1.0.12/v1.0.12_8000.3
            "mHOykQ+fgsQ/Hdrd3moQm3ZbToILc8ZwW73GIOc4DbQRZol7q1CcgX5EVeypCw7MjgUgBQ3GPyTUFk5iqTrggA==", // Metadata v1.24 | ios/1.25.0/v1.25.0_8045.2
            "mHOykQ+fgsQ/Hdrd3moQm3ZbToILc8ZwW73GIOc4DbQRZol7q1CcgX5EVeypCw7MjgUgBQ3GPyTUFk5iqTrggA==", // Metadata v1.24 | ios/1.24.0/v1.24.0_8018.2
            "74c6F59GYWkslnpVKOKZgWTKCw2/VtYbKHYzWgGBm9KYv1w9fVYsc8Rx8rfIzTZwHBh1DRhgzvOM2F8KgnlxvQ==", // Metadata v1.23 | mac/1.0.12/v1.0.12_7926.3 + crypto transformers
            "74c6F59GYWkslnpVKOKZgWTKCw2/VtYbKHYzWgGBm9KYv1w9fVYsc8Rx8rfIzTZwHBh1DRhgzvOM2F8KgnlxvQ==", // Metadata v1.22 | mac/1.0.8/v1.0.8_7886.3
            "1vruSnEV2oM6CHegPI427E2ANDYIaN4ArY/+7mbbgYjS88bEkD3Tl8OjGEYtk0Rp7v/L3DVwiBm6x3LaYaM/6A==", // Metadata v1.21 | mac/1.0.0/v1.0.0_7686.2
            "0+y3lLFY+JyTTbvVLstXWZD7GZKsQMs2IBJGwSvk1OKiNRIdqNxo962B1+QJ5zMsq7Ru37plnAujCfXNwnDwdQ==", // Metadata v1.19 | mac/1.0.0/v1.0.0_7111.2 + cascade deletion
            "0+y3lLFY+JyTTbvVLstXWZD7GZKsQMs2IBJGwSvk1OKiNRIdqNxo962B1+QJ5zMsq7Ru37plnAujCfXNwnDwdQ==", // Metadata v1.18 | mac/1.0.0/v1.0.0_6787.2
            "PKsrHx8ga9PxY3U2hsgn1uBQLDSK3G1TW8P6hRUK95yvIRx96IrL/5oLe2GuRS/tn6NIQWCxWa+t4P8t1Wcumg==", // Metadata v1.17 | mac/1.0.0/v1.0.0_6728.3
            "G/2iEtjSRxm2LeIuQO8fDGvZ+0ITxN3RhR3Ogr76UIa1/IzkaCANXYFbVu0xKR3S8hQXtLDdIXurH/Md2xnJeQ==", // Metadata v1.16 | mac/1.0.0/v1.0.0_6532.2 + transient attribute
            "G/2iEtjSRxm2LeIuQO8fDGvZ+0ITxN3RhR3Ogr76UIa1/IzkaCANXYFbVu0xKR3S8hQXtLDdIXurH/Md2xnJeQ==", // Metadata v1.15 | mac/1.0.0/v1.0.0_6338.3
        ].contains(hashDigest)
    }
    
    func hashDigest(storeAt storeFileUrl: URL) throws -> String? {
        let storeMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeFileUrl)
        return storeMetadata["NSStoreModelVersionHashesDigest"] as? String
    }
    
}
