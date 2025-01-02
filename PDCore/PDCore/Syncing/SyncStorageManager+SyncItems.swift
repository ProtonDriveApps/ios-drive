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

    @discardableResult
    func upsert(_ item: ReportableSyncItem, in moc: NSManagedObjectContext) throws -> SyncItem {
        if self.exists(with: item.id, entityName: "SyncItem", in: moc) {
            return try self.updateSyncItem(with: item, in: moc)
        } else {
            return try self.createItem(item, in: moc)
        }
    }

    private func createItem(_ item: ReportableSyncItem, in moc: NSManagedObjectContext) throws -> SyncItem {
        try moc.performAndWait {
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
            syncItem.errorDescription = item.description

            try moc.saveOrRollback()
            return syncItem
        }
    }

    func resolveItem(id: String, in moc: NSManagedObjectContext) throws {
        try moc.performAndWait {
            guard let syncItem: SyncItem = self.existing(with: [id], in: moc).first else {
                throw SyncItemError.notFound
            }
            syncItem.state = .finished
            try moc.saveOrRollback()
        }
    }

    func updateTrashState(identifier: String, state: SyncItemState, in moc: NSManagedObjectContext) throws {
        try moc.performAndWait {
            let syncItems: [SyncItem] = self.existing(with: [identifier], in: moc)
            guard let syncItem = syncItems.first else {
                throw SyncItemError.notFound
            }
            syncItem.state = state
            try moc.saveOrRollback()
        }
    }

    func updateTemporaryItem(id: String, with createdItem: ReportableSyncItem, in moc: NSManagedObjectContext) throws {
        try moc.performAndWait {
            let syncItems: [SyncItem] = self.existing(with: [id], in: moc)
            guard let syncItem = syncItems.first else {
                throw SyncItemError.notFound
            }
            // We need to switch to final `id`
            syncItem.id = createdItem.id
            syncItem.modificationTime = Date()
            syncItem.filename = createdItem.filename
            syncItem.location = createdItem.location
            syncItem.mimeType = createdItem.mimeType
            if let fileSize = createdItem.fileSize {
                syncItem.fileSize = NSNumber(value: fileSize)
            }
            syncItem.state = createdItem.state
            syncItem.fileProviderOperation = createdItem.fileProviderOperation
            syncItem.errorDescription = createdItem.description
            try moc.saveOrRollback()
        }
    }

    private func updateSyncItem(with item: ReportableSyncItem, in moc: NSManagedObjectContext) throws -> SyncItem {
        try moc.performAndWait {
            let syncItems: [SyncItem] = self.existing(with: [item.id], in: moc)
            guard let syncItem = syncItems.first else {
                throw SyncItemError.notFound
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
            syncItem.errorDescription = item.description

            try moc.saveOrRollback()
            return syncItem
        }
    }

    private func syncItems(olderThan date: Date, in moc: NSManagedObjectContext) -> [SyncItem] {
        let predicate = NSPredicate(format: "modificationTime < %@", date as NSDate)
        return fetchSyncItems(in: moc, predicate: predicate)
    }

    @discardableResult
    func deleteSyncItems(olderThan date: Date, in moc: NSManagedObjectContext) throws -> [SyncItem] {
        try moc.performAndWait {
            let oldSyncItems = syncItems(olderThan: date, in: moc)
            if !oldSyncItems.isEmpty {
                for oldItem in oldSyncItems {
                    moc.delete(oldItem)
                }
                try moc.saveOrRollback()
            }
            return oldSyncItems
        }
    }

    // MARK: Output

    func fetchSyncItems(in moc: NSManagedObjectContext, predicate: NSPredicate? = nil) -> [SyncItem] {
        return moc.performAndWait {
            let fetchRequest = NSFetchRequest<SyncItem>()
            fetchRequest.entity = SyncItem.entity()
            fetchRequest.predicate = predicate
            guard let items = try? moc.fetch(fetchRequest) else {
                return []
            }
            return items
        }
    }

    // MARK: CleanUp

    func removeSyncingDownloadedItems(in moc: NSManagedObjectContext) async throws {
        try await moc.perform {
            let statePredicate = NSPredicate(format: "stateRaw == %d", SyncItemState.inProgress.rawValue)
            let operationPredicate = NSPredicate(format: "fileProviderOperationRaw == %d", FileProviderOperation.fetchContents.rawValue)
            let predicates = [statePredicate, operationPredicate].compactMap { $0 }
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            let items = self.fetchSyncItems(in: moc, predicate: compoundPredicate)
            for item in items {
                moc.delete(item)
            }
            try moc.saveOrRollback()
        }
    }

    func cleanUpSyncingItems(in moc: NSManagedObjectContext) throws {
        try moc.performAndWait {
            let statePredicate = NSPredicate(format: "stateRaw == %d", SyncItemState.inProgress.rawValue)
            let items = self.fetchSyncItems(in: moc, predicate: statePredicate)
            for item in items {
                moc.delete(item)
            }
            try moc.saveOrRollback()
        }
    }
}
