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

public extension SyncStorageManager {

    var oldItemsRelativeDate: Date {
        Date.Past.twentyFourHours()
    }

    @discardableResult
    func updateSyncError(_ error: ReportableSyncItem, in moc: NSManagedObjectContext) async throws -> SyncItem {
        try await moc.perform {
            let syncErrors: [SyncItem] = self.existing(with: [error.id], in: moc)
            guard let syncError = syncErrors.first else {
                throw SyncItemError.notFound
            }
            syncError.modificationTime = Date()
            syncError.errorRetryCount += 1
            syncError.filename = error.filename
            syncError.mimeType = error.mimeType
            syncError.location = error.location
            syncError.fileProviderOperation = error.fileProviderOperation
            syncError.errorDescription = error.description

            try moc.saveIfNeeded()
            return syncError
        }
    }

    func deleteSyncItem(id: String, in moc: NSManagedObjectContext) async throws {
        try await moc.perform {
            if let errorToDelete: SyncItem = self.existing(with: [id], in: moc).first {
                moc.delete(errorToDelete)
                try moc.saveWithParentLinkCheck()
            }
        }
    }

    private func syncErrors(olderThan date: Date, in moc: NSManagedObjectContext) -> [SyncItem] {
        let syncState: SyncItemState = .errored
        let errorPredicate = NSPredicate(format: "stateRaw == %d", syncState.rawValue)
        let predicate = NSPredicate(format: "modificationTime < %@", date as NSDate)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            errorPredicate,
            predicate
        ])
        return fetchSyncItems(in: moc, predicate: compoundPredicate)
    }

    @discardableResult
    func deleteSyncErrors(olderThan date: Date, in moc: NSManagedObjectContext) throws -> [SyncItem] {
        try moc.performAndWait {
            let oldSyncErrors = syncErrors(olderThan: date, in: moc)
            if !oldSyncErrors.isEmpty {
                for  oldError in oldSyncErrors {
                    moc.delete(oldError)
                }
                try moc.saveWithParentLinkCheck()
            }
            return oldSyncErrors
        }
    }

    // MARK: Output

    func fetchSyncErrors(in moc: NSManagedObjectContext, predicate: NSPredicate? = nil) -> [SyncItem] {
        return moc.performAndWait {
            let syncState: SyncItemState = .errored
            let errorPredicate = NSPredicate(format: "stateRaw == %d", syncState.rawValue)
            let predicates = [errorPredicate, predicate].compactMap { $0 }
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            let fetchRequest = self.syncErrorFetchRequest(predicate: compoundPredicate)
            guard let errors = try? moc.fetch(fetchRequest) else {
                return []
            }
            return errors
        }
    }

    func syncErrorExists(with id: String, in moc: NSManagedObjectContext) -> Bool {
        return moc.performAndWait {
            let fetchRequest: NSFetchRequest<SyncItem> = self.syncErrorFetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            fetchRequest.fetchLimit = 1
            return (try? moc.count(for: fetchRequest) != 0) ?? false
        }
    }

    func syncErrorsCount(in moc: NSManagedObjectContext) -> Int {
        return moc.performAndWait {
            var totalCount: Int = 0
            let fetchRequest = self.syncErrorFetchRequest()
            if let syncErrorsCount = try? moc.count(for: fetchRequest) {
                totalCount = syncErrorsCount
            }
            return totalCount
        }
    }

    func syncErrorFetchRequest(predicate: NSPredicate? = nil) -> NSFetchRequest<SyncItem> {
        let fetchRequest = NSFetchRequest<SyncItem>()
        fetchRequest.entity = SyncItem.entity()
        let syncState: SyncItemState = .errored
        let errorPredicate = NSPredicate(format: "stateRaw == %d", syncState.rawValue)
        let predicates = [errorPredicate, predicate].compactMap { $0 }
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.predicate = compoundPredicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SyncItem.modificationTime), ascending: false)]
        return fetchRequest
    }

}
