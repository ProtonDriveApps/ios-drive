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
        case .preserve(let winner):
            switch winner {
            case .remote:
                return (node.item, true)
            case .delete where ((node as? File) != nil):
                if let newItem = newFileItemFrom(node: node) {
                    return (newItem, true)
                } else {
                    return (node.item, false)
                }
            case .delete:
                return (node.item, false)
            case .edit:
                return (node.item, true)
            }
        case .discard(let operation):
            switch operation {
            case .delete:
                return (node.item, true)
            default:
                return (node.item, false) // Temporary

            }
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
            return .preserve(winner: .remote)
        }
        switch operation {
        case .move:
            // Move-Create conflict resolution
            return .preserve(winner: .remote)
        case let .delete(parent: isParent):
            if isParent {
                return .preserve(winner: .edit)
            } else {
                return .discard(operation: .delete(parent: false))
            }
        case .edit:
            return .preserve(winner: .remote)
        default:
            return .discard(operation: .edit(nil))
        }
    }

    private func moveConflictStrategy(on existingItem: NSFileProviderItem, with operation: ConflictingOperation?) -> ConflictResolutionStrategy {
        switch operation {
        case .edit:
            // Move-Move conflict resolution
            return .preserve(winner: .remote)
        default: // Temporary
            return .discard(operation: .move(nil))
        }
    }

    // [DRVIOS-1770] Delete-Delete Pseudo conflict
    private func deleteConflictStrategy(on existingItem: NSFileProviderItem, parent: Bool, operation: ConflictingOperation) -> ConflictResolutionStrategy {
        return .discard(operation: .delete(parent: false))
    }

    private func newFileItemFrom(node: Conflicting) -> NSFileProviderItem? {
        guard let file = node as? File else {
            return nil
        }
        return NodeItem(node: file)
    }

    // MARK: - Conflict folder

    func createConflictFolder(under parentFolder: Folder) async throws -> Folder {
        let name = "Conflict"
        return try await createFolder(named: name, under: parentFolder)
    }

}
