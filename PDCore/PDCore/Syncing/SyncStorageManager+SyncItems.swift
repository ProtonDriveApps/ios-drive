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
    func upsert(_ item: ReportableSyncItem, in moc: NSManagedObjectContext) async throws -> SyncItem {
        if self.exists(with: item.id, entityName: "SyncItem", in: moc) {
            return try await self.updateSyncItem(with: item, in: moc)
        } else {
            return try await self.createItem(item, in: moc)
        }
    }

    private func createItem(_ item: ReportableSyncItem, in moc: NSManagedObjectContext) async throws -> SyncItem {
        try await moc.perform {
            let syncItem: SyncItem = self.new(with: item.id, by: #keyPath(SyncItem.id), in: moc)
            syncItem.modificationTime = item.modificationTime
            syncItem.filename = item.filename
            syncItem.location = item.location
            syncItem.mimeType = item.mimeType
            syncItem.fileProviderOperation = item.fileProviderOperation
            syncItem.state = item.state
            syncItem.errorDescription = item.description

            try moc.saveWithParentLinkCheck()
            return syncItem
        }
    }

    func updateSyncItemState(id: String, state: SyncItemState, in moc: NSManagedObjectContext) async throws {
        try await moc.perform {
            if let item: SyncItem = self.existing(with: [id], in: moc).first {
                item.state = state
                try moc.saveWithParentLinkCheck()
            }
        }
    }

    func resolveItem(id: String, in moc: NSManagedObjectContext) async throws {
        try await moc.perform {
            guard let syncItem: SyncItem = self.existing(with: [id], in: moc).first else {
                throw SyncItemError.notFound
            }
            syncItem.state = .finished
            try moc.saveWithParentLinkCheck()
        }
    }

    private func updateSyncItem(with item: ReportableSyncItem, in moc: NSManagedObjectContext) async throws -> SyncItem {
        try await moc.perform {
            let syncItems: [SyncItem] = self.existing(with: [item.id], in: moc)
            guard let syncItem = syncItems.first else {
                throw SyncItemError.notFound
            }
            syncItem.modificationTime = item.modificationTime
            syncItem.filename = item.filename
            syncItem.location = item.location
            syncItem.mimeType = item.mimeType
            syncItem.fileProviderOperation = item.fileProviderOperation
            syncItem.state = item.state
            syncItem.errorDescription = item.description

            try moc.saveWithParentLinkCheck()
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
                try moc.saveWithParentLinkCheck()
            }
            return oldSyncItems
        }
    }

    func syncItemFetchRequest(predicate: NSPredicate? = nil, limit: Int) -> NSFetchRequest<SyncItem> {
        let fetchRequest = NSFetchRequest<SyncItem>()
        fetchRequest.entity = SyncItem.entity()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SyncItem.modificationTime), ascending: false)]
        fetchRequest.fetchLimit = limit
        fetchRequest.predicate = predicate
        return fetchRequest
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

}
