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

public struct PersistentHistoryMerger {

    public let backgroundContext: NSManagedObjectContext
    public let viewContext: NSManagedObjectContext
    public let currentTarget: AppTarget
    public let userDefaults: UserDefaults

    @discardableResult
    public func merge() throws -> [NSPersistentHistoryTransaction] {
        let fromDate = userDefaults.lastHistoryTransactionTimestamp(for: currentTarget) ?? .distantPast
        let fetcher = PersistentHistoryFetcher(context: backgroundContext, fromDate: fromDate)
        let history = try fetcher.fetch()

        guard !history.isEmpty else {
            Log.debug("No history transactions found to merge for target \(currentTarget)", domain: .storage)
            return []
        }

        Log.debug("Merging \(history.count) persistent history transactions for target \(currentTarget)", domain: .storage)

        history.merge(into: backgroundContext)

        viewContext.perform {
            history.merge(into: self.viewContext)
        }

        guard let lastTimestamp = history.last?.timestamp else { return [] }
        userDefaults.updateLastHistoryTransactionTimestamp(for: currentTarget, to: lastTimestamp)

        return history
    }
}
