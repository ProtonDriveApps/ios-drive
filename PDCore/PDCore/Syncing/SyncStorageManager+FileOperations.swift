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

import CoreData

public extension SyncStorageManager {

    /// If an item with a given identifier exists, it gets updated - otherwise it gets inserted.
    /// An update happens only if `matches(item)` evaluates to `true`.
    func upsert(_ item: ReportableSyncItem, updateIf matches: (SyncItem) -> Bool = { _ in true }, in moc: NSManagedObjectContext? = nil) {
        do {
            let moc = moc ?? self.mainContext
            if self.exists(with: item.id, entityName: "SyncItem", in: moc) {
                Log.trace("Upsert - Updating \(item.filename)")
                try self.update(syncItem: item, if: matches, in: moc)
            } else {
                Log.trace("Upsert - Creating \(item.filename)")
                try self.createItem(item, in: moc)
            }
        } catch {
            Log.error("Failed to upsert", error: error, domain: .syncing)
        }
    }

    func updateTrash(identifier: String, in moc: NSManagedObjectContext? = nil) {
        Log.trace(identifier)
        do {
            let moc = moc ?? self.mainContext

            try moc.performAndWait {
                let syncItems: [SyncItem] = self.existing(with: [identifier], in: moc)
                guard let syncItem = syncItems.first else {
                    throw SyncItemError.notFound
                }
                syncItem.state = .finished
                syncItem.progress = 100
                try moc.saveOrRollback()
            }
        } catch {
            Log.error("Failed to updateTrash", error: error, domain: .syncing)
        }
    }

    func updateProgress(identifier: String, progress: Progress, in moc: NSManagedObjectContext? = nil) {
        Log.trace(identifier)

        let moc = moc ?? self.mainContext

        do {
            try moc.performAndWait {
                let syncItems: [SyncItem] = self.existing(with: [identifier], in: moc)
                guard let syncItem = syncItems.first else {
                    throw SyncItemError.notFound
                }
                let progressPercentage: Int
                if progress.totalUnitCount > 0 {
                    progressPercentage = Int(Double(progress.completedUnitCount) / Double(progress.totalUnitCount) * 100)
                } else {
                    // if totalUnitCount is zero, it's because the file size is zero
                    progressPercentage = 100
                }

                syncItem.progress = progressPercentage
                try moc.saveOrRollback()
            }
        } catch {
            Log.error("Failed to update progress", error: error, domain: .syncing)
        }
    }

    func updateItem(identifiedBy temporaryIdentifier: String, to createdItem: ReportableSyncItem, in moc: NSManagedObjectContext? = nil) {
        Log.trace(temporaryIdentifier)

        let moc = moc ?? self.mainContext

        do {
            try moc.performAndWait {
                let syncItems: [SyncItem] = self.existing(with: [temporaryIdentifier], in: moc)
                guard let syncItem = syncItems.first else {
                    throw SyncItemError.notFound
                }
                // Replace temporary id with final one.
                syncItem.id = createdItem.id
                syncItem.modificationTime = Date()
                syncItem.filename = createdItem.filename
                syncItem.location = createdItem.location
                syncItem.mimeType = createdItem.mimeType
                if let fileSize = createdItem.fileSize {
                    syncItem.fileSize = NSNumber(value: fileSize)
                }
                syncItem.state = createdItem.state
                syncItem.progress = createdItem.progress
                syncItem.fileProviderOperation = createdItem.fileProviderOperation
                syncItem.errorDescription = createdItem.errorDescription
                try moc.saveOrRollback()
            }
        } catch {
            Log.error("Failed to update item", error: error, domain: .syncing)
        }
    }

    func updateLocation(identifier: String, to location: String, in moc: NSManagedObjectContext? = nil) {
        Log.trace(identifier)

        let moc = moc ?? self.mainContext

        do {
            try moc.performAndWait {
                let syncItems: [SyncItem] = self.existing(with: [identifier], in: moc)
                guard let syncItem = syncItems.first else {
                    throw SyncItemError.notFound
                }
                syncItem.location = location
                try moc.saveOrRollback()
            }
        } catch {
            Log.error("Failed to update location", error: error, domain: .syncing)
        }
    }

    // MARK: - Private

    private func update(syncItem item: ReportableSyncItem, if matches: (SyncItem) -> Bool, in moc: NSManagedObjectContext) throws {
        Log.trace(item.filename)

        return try moc.performAndWait {
            let syncItems: [SyncItem] = self.existing(with: [item.id], in: moc)
            guard let syncItem = syncItems.first else {
                throw SyncItemError.notFound
            }

            guard matches(syncItem) else {
                Log.trace("Skipping update - \(item.filename)")
                return
            }

            syncItem.modificationTime = Date()
            syncItem.filename = item.filename
            syncItem.location = item.location
            syncItem.mimeType = item.mimeType
            if let fileSize = item.fileSize {
                syncItem.fileSize = NSNumber(value: fileSize)
            }
            syncItem.fileProviderOperation = item.fileProviderOperation
            syncItem.state = item.state
            syncItem.errorDescription = item.errorDescription
            syncItem.progress = item.progress

            try moc.saveOrRollback()
        }
    }

    private func createItem(_ item: ReportableSyncItem, in moc: NSManagedObjectContext) throws {
        Log.trace(item.filename)

        return try moc.performAndWait {
            let syncItem: SyncItem = self.new(with: item.id, by: #keyPath(SyncItem.id), in: moc)
            syncItem.modificationTime = item.modificationTime
            syncItem.filename = item.filename
            syncItem.location = item.location
            syncItem.mimeType = item.mimeType
            if let fileSize = item.fileSize {
                syncItem.fileSize = NSNumber(value: fileSize)
            }
            syncItem.fileProviderOperation = item.fileProviderOperation
            syncItem.state = item.state
            syncItem.progress = item.progress
            syncItem.errorDescription = item.errorDescription

            try moc.saveOrRollback()
        }
    }
}
