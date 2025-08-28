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

import CoreData
import ProtonCoreUtilities

struct InvalidMetadataRelationshipError: LocalizedError {
    let linkID: String
    let shareID: String

    var errorDescription: String? {
        """
        InvalidMetadataRelationshipError 🛠️
        linkID: \(linkID)
        shareID: \(shareID)
        """
    }
}

public extension NSManagedObjectContext {
#if DEBUG
    /// Counts how many times the context is saved, to enable detecting when it happens too much.
    static var saveCounter = Atomic<Int>(0)
#endif

    /// Only performs a save if there are changes to commit.
    /// - Returns: `true` if a save was needed. Otherwise, `false`.
    func saveIfNeeded() throws {
        guard hasChanges else { return }

#if DEBUG
        Self.saveCounter.mutate { $0 += 1 }
        Log.trace("Will save... \(Self.saveCounter.value.description)")
#else
        Log.trace("Will save...")
#endif

        #if os(iOS)
        guard !(persistentStoreCoordinator?.persistentStores.isEmpty ?? true) else {
            Log.error("Executing save on moc which doesn't have a persistent store", error: nil, domain: .storage)
            return
        }
        #endif

        try save()
        Log.trace("Did save")
    }

    /// Attempts to save the changes in the NSManagedObjectContext
    /// on failure rollsback all the changes and throws the error that caused the failure
    func saveOrRollback() throws {
        do {
            try saveIfNeeded()
        } catch {
            rollback()
            throw error
        }
    }
}

public extension NSManagedObjectContext {

    func childContext(ofType type: NSManagedObjectContextConcurrencyType = .privateQueueConcurrencyType) -> NSManagedObjectContext {
        let child = NSManagedObjectContext(concurrencyType: type)
        child.parent = self
        child.automaticallyMergesChangesFromParent = true
        child.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return child
    }

}
