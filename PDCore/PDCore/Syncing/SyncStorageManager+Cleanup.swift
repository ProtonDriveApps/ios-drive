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

extension SyncStorageManager {

    public func cleanUpOnLaunch() {
        Log.trace()

        cleanUpExpiredItems()
        cleanUpInProgressItems()
    }

    public func cleanUpOnPause() {
        Log.trace()

        cleanUpInProgressItems()
    }

    public func cleanUpInProgressItems() {
        Log.trace()

        let statePredicate = NSPredicate(format: "stateRaw == %d", SyncItemState.inProgress.rawValue)
        delete(with: statePredicate, in: backgroundContext)
    }

    public func cleanUpExpiredItems() {
        Log.trace()

        // Items with an error also qualify as expired, because whatever error caused them
        // no longer matters at restart.
        let cutoffDate = Date.Past.twentyFourHours()
        let predicate = NSPredicate(format: "modificationTime < %@", cutoffDate as NSDate)
        delete(with: predicate, in: backgroundContext)
    }

    public func cleanUpErrors() {
        Log.trace()

        let errorPredicate = NSPredicate(format: "stateRaw == %d", SyncItemState.errored.rawValue)
        delete(with: errorPredicate, in: backgroundContext)
    }

    public func cleanUp() async {
        Log.trace()
        
        await self.mainContext.perform {
            self.mainContext.reset()
        }

        await self.backgroundContext.perform {
            self.backgroundContext.reset()

            [SyncItem.self].forEach { entity in
                let request = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity)))
                request.resultType = .resultTypeObjectIDs
                do {
                    _ = try self.persistentContainer.persistentStoreCoordinator.execute(request, with: self.backgroundContext)
                } catch {
                    assert(false, "Could not perform batch deletion after logout")
                }
            }
        }
    }
}
