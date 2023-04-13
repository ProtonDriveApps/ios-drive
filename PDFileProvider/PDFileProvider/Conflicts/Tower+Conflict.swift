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

import PDCore
import FileProvider

extension Tower {

    // MARK: - Detect conflict

    func conflictStrategy(for existingItem: NSFileProviderItem, _ conflictOperation: ConflictingOperation) throws -> ConflictResolutionStrategy {

        switch conflictOperation {
        case .create(let operation):
            return createConflictStrategy(on: existingItem, with: operation)
        case .edit(let operation):
            return editConflictStrategy(on: existingItem, with: operation)
        case .move(let operation):
            return moveConflictStrategy(on: existingItem, with: operation)
        case .delete(let isParent):
            return deleteConflictStrategy(on: existingItem, parent: isParent, operation: conflictOperation)
        }
    }

    // MARK: - Resolve conflict

    func resolveConflict(on node: Conflicting, with strategy: ConflictResolutionStrategy) -> (NSFileProviderItem, Bool) {

        switch strategy {
        case .merge:
            return (node.item, true)
        case .discard, .preserve:  // Temporary
            return (node.item, false)
        }
    }

    private func createConflictStrategy(on existingItem: NSFileProviderItem, with operation: ConflictingOperation?) -> ConflictResolutionStrategy {
        // [DRVIOS-1768] Create-Create file
        if operation == nil {
            // Create-Create Pseudo conflict for folder and Create-Create Name clash conflict for a file (renaming)
            return existingItem.isFolder ? .merge : .preserve(winner: .remote)
        }
        // [DRVIOS-1779] Create/parentDelete file/folder conflict resolution
        return .preserve(winner: .delete)
    }

    private func editConflictStrategy(on existingItem: NSFileProviderItem, with operation: ConflictingOperation?) -> ConflictResolutionStrategy {
        guard let operation = operation else {
            return .discard(operation: .create(nil))
        }
        return .discard(operation: .edit(nil))
    }

    private func moveConflictStrategy(on existingItem: NSFileProviderItem, with operation: ConflictingOperation?) -> ConflictResolutionStrategy {
        return .discard(operation: .move(nil))
    }

    // [DRVIOS-1770] Delete-Delete Pseudo conflict
    private func deleteConflictStrategy(on existingItem: NSFileProviderItem, parent: Bool, operation: ConflictingOperation) -> ConflictResolutionStrategy {
        return .discard(operation: .delete(parent: false))
    }

}
