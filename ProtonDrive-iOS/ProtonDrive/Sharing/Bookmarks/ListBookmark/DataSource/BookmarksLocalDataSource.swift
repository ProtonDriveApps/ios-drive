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
import PDCore
import CoreData

protocol BookmarksLocalDataSource {
    func saveBookmarks(_ bookmarks: [Bookmark]) async throws
}

extension StorageManager: BookmarksLocalDataSource {

    func saveBookmarks(_ bookmarks: [Bookmark]) async throws {
        let parentContext = backgroundContext

        // Step 1: Fetch existing bookmarks and determine which to delete
        try await parentContext.perform {
            let fetchRequest = NSFetchRequest<CoreDataBookmark>()
            fetchRequest.entity = CoreDataBookmark.entity()

            do {
                let existingBookmarks = try parentContext.fetch(fetchRequest)
                let existingLinkIDs = Set(existingBookmarks.map { $0.id })
                let newLinkIDs = Set(bookmarks.map { $0.token.linkID })

                let linkIDsToDelete = existingLinkIDs.subtracting(newLinkIDs)

                for bookmark in existingBookmarks where linkIDsToDelete.contains(bookmark.id) {
                    parentContext.delete(bookmark)
                }

                try parentContext.saveOrRollback()
            } catch {
                Log.error("Failed to delete outdated bookmarks", error: error, domain: .storage)
                throw error
            }
        }

        // Step 2: Process new bookmarks in batches
        for batch in bookmarks.splitInGroups(of: 10) {
            try await processBatch(batch, parentContext: parentContext)
        }
    }

    private func processBatch(_ batch: [Bookmark], parentContext: NSManagedObjectContext) async throws {
        // Create a child context for processing
        let childContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        childContext.parent = parentContext

        try await childContext.perform {
            for bookmark in batch {
                // Create the Core Data object in the child context
                let coreDataBookmark = CoreDataBookmark.makeBookmark(bookmark, in: childContext)

                // Perform decryption
                let password = try coreDataBookmark.decryptPassword()
                let decryptedName = try coreDataBookmark.decryptPGPName(withPassword: password)
                coreDataBookmark.locallyEncryptedName = decryptedName
            }

            // Save the child context to propagate changes to the parent context
            do {
                try childContext.saveOrRollback()
            } catch {
                Log.error(error: error, domain: .storage)
                throw DriveError("Failed to obtain bookmark")
            }
        }

        // Save changes from the parent context to the persistent store
        try await parentContext.perform {
            do {
                try parentContext.saveOrRollback()
            } catch {
                throw error
            }
        }
    }
}
