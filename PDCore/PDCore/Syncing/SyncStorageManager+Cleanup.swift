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

    public func cleanUpOnLaunch() async {
        Log.trace()

        await cleanUpExpiredItems()
        await cleanUpInProgressItems()
    }

    public func cleanUpOnPause() async {
        Log.trace()

        await cleanUpInProgressItems()
    }

    public func cleanUpInProgressItems() async {
        Log.trace()

        // Also clean paused items — they represent interrupted operations that won't resume
        // from where they left off after a restart (the file provider system retries from scratch).
        let statePredicate = NSPredicate(
            format: "stateRaw == %d OR stateRaw == %d",
            SyncItemState.inProgress.rawValue,
            SyncItemState.paused.rawValue
        )
        await delete(with: statePredicate, in: presentationContext)
    }

    public func cleanUpExpiredItems() async {
        Log.trace()

        // Items with an error also qualify as expired, because whatever error caused them
        // no longer matters at restart.
        let cutoffDate = Date.Past.twentyFourHours()
        let predicate = NSPredicate(format: "modificationTime < %@", cutoffDate as NSDate)
        await delete(with: predicate, in: presentationContext)
    }

    public func cleanUpErrors() async {
        Log.trace()

        let errorPredicate = NSPredicate(format: "stateRaw == %d", SyncItemState.errored.rawValue)
        await delete(with: errorPredicate, in: presentationContext)
    }

    public func cleanUp() async {
        Log.trace()

        let persistentContainer = persistentContainer

        await backgroundContextPool.withContext { context in
            await context.perform {
                // in memory stores do not support the NSBatchDeleteRequest
                if context.isInMemory {
                    [SyncItem.self].forEach { entity in
                        let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: entity))
                        do {
                            let result = try context.fetch(request)
                            result.forEach { context.delete($0) }
                            try context.save()
                        } catch {
                            assert(false, "Could not perform one-by-one deletion after logout")
                        }
                    }
                } else {
                    [SyncItem.self].forEach { entity in
                        let request = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity)))
                        request.resultType = .resultTypeObjectIDs
                        do {
                            _ = try persistentContainer.persistentStoreCoordinator.execute(request, with: context)
                        } catch {
                            assert(false, "Could not perform batch deletion after logout")
                        }
                    }
                }
            }
        }
    }
}
