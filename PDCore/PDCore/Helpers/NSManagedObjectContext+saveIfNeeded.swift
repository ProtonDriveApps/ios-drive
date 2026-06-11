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
    static var saveCounter = Atomic<[ObjectIdentifier: Int]>([:])
#endif

    /// Only performs a save if there are changes to commit.
    /// - Returns: `true` if a save was needed. Otherwise, `false`.
    func saveIfNeeded(
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) throws {
        guard hasChanges else { return }

#if DEBUG
        let identifier = ObjectIdentifier(self)
        Self.saveCounter.mutate { $0[identifier, default: 0] += 1 }
        let saveCounter = Self.saveCounter.value[identifier]?.description
        Log.trace("Will save. Context: \(identifier), Counter: \(saveCounter)", file: file, function: function, line: line)
#else
        Log.trace("Will save...")
#endif

        #if os(iOS)
        guard !(persistentStoreCoordinator?.persistentStores.isEmpty ?? true) else {
            Log.error("Executing save on moc which doesn't have a persistent store", error: nil, domain: .storage, file: file, function: function, line: line)
            return
        }
        #endif

        try save()
#if DEBUG
        Log.trace("Did save. Counter: \(saveCounter)", file: file, function: function, line: line)
#endif
    }

    /// Attempts to save the changes in the NSManagedObjectContext
    /// on failure rollsback all the changes and throws the error that caused the failure
    func saveOrRollback(
        file: String = #filePath,
        function: String = #function,
        line: Int = #line
    ) throws {
        do {
            try saveIfNeeded(file: file, function: function, line: line)
        } catch {
            rollback()
            throw error
        }
    }
    
    func resetCounter() {
        let identifier = ObjectIdentifier(self)
#if DEBUG
        Self.saveCounter.mutate { $0[identifier, default: 0] = 0 }
#endif
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
