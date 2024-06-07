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

public struct PersistentHistoryCleaner {

    let context: NSManagedObjectContext
    let targets: [AppTarget]
    let userDefaults: UserDefaults

    /// Cleans up the persistent history by deleting the transactions that have been merged into each target.
    public func clean() throws {
        try context.performAndWait {
            guard let timestamp = userDefaults.lastCommonTransactionTimestamp(in: targets) else {
                Log.debug("Cancelling deletions as there is no common transaction timestamp", domain: .storage)
                return
            }

            let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: timestamp)
            Log.debug("Deleting persistent history using common timestamp \(timestamp)", domain: .storage)

            try context.execute(deleteHistoryRequest)

            resetTimestamp()
        }
    }

    public func cleanEverything() throws {
        try context.performAndWait {
            let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: Date())
            try context.execute(deleteHistoryRequest)
            resetTimestamp()
        }
    }

    func resetTimestamp() {
        targets.forEach { target in
            userDefaults.updateLastHistoryTransactionTimestamp(for: target, to: nil)
        }
    }
}
