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

    func fetch(with predicate: NSPredicate, in moc: NSManagedObjectContext) -> [SyncItem] {
        Log.trace("Predicate: \(predicate.description)")

        return moc.performAndWait {
            guard let items = try? moc.fetch(fetchRequest(with: predicate)) else {
                return []
            }
            return items
        }
    }

    func fetch<T>(property: String, with predicate: NSPredicate, in moc: NSManagedObjectContext) -> [T] {
        Log.trace("Predicate: \(predicate.description)")

        return moc.performAndWait {
            guard let propertyValues = try? moc.fetch(self.fetchPropertiesRequest([property], with: predicate)) else {
                return []
            }
            let dict = propertyValues as? [NSDictionary] ?? []
            return dict.compactMap { $0[property] as? T }
        }
    }
    func count(with predicate: NSPredicate, in moc: NSManagedObjectContext) -> Int {
        Log.trace("Predicate: \(predicate.description)")

        return moc.performAndWait {
            var count: Int = 0
            if let fetchedCount = try? moc.count(for: fetchRequest(with: predicate)) {
                count = fetchedCount
            }
            return count
        }
    }

    func max(for field: String, with predicate: NSPredicate, in moc: NSManagedObjectContext) -> Double? {
        Log.trace("Predicate: \(predicate.description)")

        return moc.performAndWait {
            let keyPathExpression = NSExpression(forKeyPath: field)
            let maxExpression = NSExpression(forFunction: "max:", arguments: [keyPathExpression])
            let expressionDescription = NSExpressionDescription()
            expressionDescription.name = "maxValue"
            expressionDescription.expression = maxExpression
            expressionDescription.expressionResultType = .doubleAttributeType

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SyncItem")
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = [expressionDescription]
            fetchRequest.predicate = predicate

            if let results = try? moc.fetch(fetchRequest) as? [[String: Any]],
               let maxValue = results.first?["maxValue"] as? Double {
                return maxValue
            }
            return nil
        }
    }

    public func delete(id: String) {
        let predicate = NSPredicate(format: "%K == %@", #keyPath(SyncItem.id), "enumerateItems")
        delete(with: predicate, in: backgroundContext)
    }

    @discardableResult
    func delete(with predicate: NSPredicate, in moc: NSManagedObjectContext) -> Int {
        Log.trace("Predicate: \(predicate.description)")

        do {
            return try moc.performAndWait {
                let items = self.fetch(with: predicate, in: moc)
                Log.trace("Found \(items.count) items")
                if !items.isEmpty {
                    for item in items {
                        moc.delete(item)
                    }
                    try moc.saveOrRollback()
                }
                return items.count
            }
        } catch {
            Log
                .error("Error deleting sync items", domain: .syncing, context: LogContext(predicate.description))
            return 0
        }
    }

    private func fetchPropertiesRequest(_ properties: [String], with predicate: NSPredicate) -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SyncItem")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = properties
        fetchRequest.predicate = predicate
        return fetchRequest
    }

    private func fetchRequest(with predicate: NSPredicate) -> NSFetchRequest<SyncItem> {
        let fetchRequest = SyncItem.fetchRequest()
        fetchRequest.predicate = predicate
        return fetchRequest
    }
}
