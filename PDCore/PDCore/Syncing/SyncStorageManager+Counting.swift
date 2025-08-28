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
    func countSyncsInProgress() -> Int {
        Log.trace()
        let predicate = NSPredicate(format: "inProgress == %d", true)
        return count(with: predicate, in: backgroundContext)
    }

    func countEnumerationsInProgress() -> Int {
        Log.trace()
        let predicate = NSPredicate(format: "(fileProviderOperationRaw == %d OR fileProviderOperationRaw == %d) AND inProgress == %d", FileProviderOperation.enumerateItems.rawValue, FileProviderOperation.enumerateChanges.rawValue, true)
        return count(with: predicate, in: backgroundContext)
    }

    var itemEnumerationProgress: String? {
        let predicate = NSPredicate(format: "%K == %@", #keyPath(SyncItem.id), "enumerateItems")
        let fetchedProgress: [String] = fetch(property: #keyPath(SyncItem.filename), with: predicate, in: backgroundContext)
        return fetchedProgress.first
    }

    func countSyncErrors() -> Int {
        Log.trace()
        return count(with: NSPredicate(format: "stateRaw == %d", SyncItemState.errored.rawValue), in: backgroundContext)
    }

    func countFinishedDeletions() -> Int {
        Log.trace()
        return count(with: NSPredicate(format: "fileProviderOperationRaw == %d AND stateRaw == %d", FileProviderOperation.delete.rawValue, SyncItemState.finished.rawValue), in: backgroundContext)
    }

    func lastSyncTime() -> TimeInterval? {
        Log.trace()
        let predicate = NSPredicate(value: true)

        guard let maxValue = max(for: "modificationTime", with: predicate, in: backgroundContext) else {
            return nil
        }
        // Map from timeIntervalSinceReferenceDate, as stored by CoreData, to timeIntervalSince1970
        return Date(timeIntervalSinceReferenceDate: maxValue).timeIntervalSince1970
    }
}
