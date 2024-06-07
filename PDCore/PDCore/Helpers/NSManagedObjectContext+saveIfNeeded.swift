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

    /// Only performs a save if there are changes to commit.
    /// - Returns: `true` if a save was needed. Otherwise, `false`.
    func saveIfNeeded() throws {
        guard hasChanges else { return }
        try saveWithParentLinkCheck()
    }
    
    func saveWithParentLinkCheck() throws {
        try registeredObjects
            .forEach { object in
                if let node = object as? Node,
                    node.parentLink == nil,
                    !node.nodeHash.isEmpty,
                    node.isInserted || node.isUpdated {
                    // We may log this error two times, this first time is to give us indication as soon as possible about the issue
                    // everytime it happens. The next error is not always logged, so loging in this is a more conservative approach.
                    Log.error(InvalidMetadataRelationshipError(linkID: node.id, shareID: node.shareID), domain: .storage)

                    // This error will keep being sent to and will be handled as part of usual flow that already exists.
                    throw DriveError("Item with a node hash (so not root) but without a parent link, this should not happen!")
                }
            }
        try save()
    }

    /// Attempts to save the changes in the NSManagedObjectContext
    /// on failure rollsback all the changes and throws the error that caused the failure
    func saveOrRollback() throws {
        do {
            guard hasChanges else { return }
            try saveWithParentLinkCheck()
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
