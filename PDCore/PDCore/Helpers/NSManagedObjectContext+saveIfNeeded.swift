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

import CoreData

public extension NSManagedObjectContext {

    /// Only performs a save if there are changes to commit.
    /// - Returns: `true` if a save was needed. Otherwise, `false`.
    func saveIfNeeded() throws {
        guard hasChanges else { return }
        try save()
    }

    /// Attempts to save the changes in the NSManagedObjectContext
    /// on failure rollsback all the changes and throws the error that caused the failure
    func saveOrRollback() throws {
        do {
            guard hasChanges else { return }
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}

public extension NSManagedObjectContext {

    func childContext(ofType type: NSManagedObjectContextConcurrencyType = .privateQueueConcurrencyType) -> NSManagedObjectContext {
        let child = NSManagedObjectContext(concurrencyType: type)
        child.parent = self
        return child
    }

}
