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

import FileProvider
import PDCore

extension ItemActionsOutlet: ConflictResolution {

    // swiftlint:disable:next function_parameter_count
    public func resolveConflict(tower: Tower, between item: NSFileProviderItem, with url: URL?, and conflictingNode: Node?, applying action: ResolutionAction, fields: NSFileProviderItemFields, progress: Progress?) async throws -> NSFileProviderItem {
        switch action {
        case .ignore:
            // if the conflict is direct, then `conflictingNode` will be the remote version of item,
            // however in the case of indirect conflicts, will represent a different node
            guard let remoteNode = await tower.node(itemIdentifier: item.itemIdentifier) else {
                guard let conflictingNode else {
                    throw Errors.itemDeleted
                }
                return try NodeItem(node: conflictingNode)
            }

            let (state, isTrashInheriting) = remoteNode.moc!.performAndWait {
                return (remoteNode.state, remoteNode.isTrashInheriting)
            }
            guard state != .deleted && !isTrashInheriting else {
                throw Errors.itemTrashed
            }
            
            return try NodeItem(node: remoteNode)

        case .recreate:
            guard let parent = await tower.parentFolder(of: item) else {
                throw Errors.parentNotFound
            }
            if item.isFolder {
                let recreatedFolder = try await tower.createFolder(named: item.filename, under: parent)
                return try NodeItem(node: recreatedFolder)
            } else {
                let (recreatedFile, context) = try await fileCreationProvider().createFile(
                    tower: tower, item: item, with: url, under: parent, progress: progress, logOperation: true
                )
                return try await context.perform {
                    try NodeItem(node: recreatedFile)
                }
            }

        case .createWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.conflictName(with: (conflictingNode != nil) ? .nameClash : .edit))
            guard let parent = await tower.parentFolder(of: item) else {
                throw Errors.parentNotFound
            }
            if item.isFolder {
                let createdNode = try await tower.createFolder(named: newItem.filename, under: parent)
                return try NodeItem(node: createdNode)
            } else {
                let (createdFile, context) = try await fileCreationProvider().createFile(
                    tower: tower, item: newItem, with: url, under: parent, progress: progress, logOperation: true
                )
                return try await context.perform {
                    try NodeItem(node: createdFile)
                }
            }

        case .renameWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.conflictName(with: .nameClash))
            guard let nodeIdentifier = tower.nodeIdentifier(for: newItem.itemIdentifier) else {
                assertionFailure("Could not create nodeIdentifier from newItem.itemIdentifier: \(newItem.itemIdentifier.debugDescription)")
                throw NSFileProviderError(.noSuchItem)
            }

            _ = try await tower.rename(node: nodeIdentifier, cleartextName: newItem.filename)

            return newItem

        case .moveAndRenameWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.conflictName(with: .nameClash))
            guard let nodeIdentifier = tower.nodeIdentifier(for: newItem.itemIdentifier) else {
                assertionFailure("Could not create nodeIdentifier from newItem.itemIdentifier: \(newItem.itemIdentifier.debugDescription)")
                throw NSFileProviderError(.noSuchItem)
            }

            guard let newParent = await tower.parentFolder(of: newItem) else {
                throw Errors.parentNotFound
            }

            _ = try await tower.move(nodeID: nodeIdentifier, under: newParent, withNewName: newItem.filename)

            return newItem
        }
    }
    
}
