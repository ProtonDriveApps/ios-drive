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
import CoreData

extension ItemActionsOutlet: ConflictResolution {

    // swiftlint:disable:next function_parameter_count
    public func resolveConflict(tower: Tower, between item: NSFileProviderItem, with url: URL?, and conflictingNode: Node?, applying action: ResolutionAction, fields: NSFileProviderItemFields, progress: Progress?, moc: NSManagedObjectContext) async throws -> NSFileProviderItem {
        switch action {
        case .ignore:
            // if the conflict is direct, then `conflictingNode` will be the remote version of item,
            // however in the case of indirect conflicts, will represent a different node
            guard let remoteNode = await tower.node(itemIdentifier: item.itemIdentifier, in: moc) else {
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
            guard let parent = await tower.parentFolder(of: item, in: moc) else {
                throw Errors.parentNotFound(identifier: item.parentItemIdentifier)
            }
            if item.isFolder {
                let recreatedFolder = try await tower.createFolder(named: item.filename, under: parent, moc: moc)
                return try NodeItem(node: recreatedFolder)
            } else {
                let recreatedFile = try await fileCreationProvider().createFile(
                    tower: tower, item: item, with: url, under: parent, progress: progress, logOperation: true, moc: moc
                )
                return try await moc.perform {
                    try NodeItem(node: recreatedFile)
                }
            }

        case .createWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.conflictName(with: (conflictingNode != nil) ? .nameClash : .edit))
            guard let parent = await tower.parentFolder(of: item, in: moc) else {
                throw Errors.parentNotFound(identifier: item.parentItemIdentifier)
            }
            if item.isFolder {
                let createdNode = try await tower.createFolder(named: newItem.filename, under: parent, moc: moc)
                return try NodeItem(node: createdNode)
            } else {
                let createdFile = try await fileCreationProvider().createFile(
                    tower: tower, item: newItem, with: url, under: parent, progress: progress, logOperation: true, moc: moc
                )
                return try await moc.perform {
                    try NodeItem(node: createdFile)
                }
            }

        case .renameWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.conflictName(with: .nameClash))
            guard let nodeIdentifier = tower.nodeIdentifier(for: newItem.itemIdentifier, moc: moc) else {
                assertionFailure("Could not create nodeIdentifier from newItem.itemIdentifier: \(newItem.itemIdentifier.debugDescription)")
                throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: newItem.itemIdentifier)
            }

            _ = try await tower.rename(node: nodeIdentifier, cleartextName: newItem.filename, moc: moc)

            return newItem

        case .moveAndRenameWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.conflictName(with: .nameClash))
            guard let nodeIdentifier = tower.nodeIdentifier(for: newItem.itemIdentifier, moc: moc) else {
                assertionFailure("Could not create nodeIdentifier from newItem.itemIdentifier: \(newItem.itemIdentifier.debugDescription)")
                throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: newItem.itemIdentifier)
            }

            guard let newParent = await tower.parentFolder(of: newItem, in: moc) else {
                throw Errors.parentNotFound(identifier: newItem.parentItemIdentifier)
            }

            // tower.move no-ops silently when newParent == currentParent (Tower+Nodes.swift),
            // so the rename would be lost. Use tower.rename instead,
            // which always executes and carries name + MIME in one call.
            guard let existingNode = await tower.node(itemIdentifier: newItem.itemIdentifier, in: moc),
                  let nodeMoc = existingNode.moc else {
                throw Errors.nodeNotFound(identifier: newItem.itemIdentifier)
            }
            let currentParentID: NodeIdentifier? = nodeMoc.performAndWait { existingNode.parentNode?.identifier }
            if currentParentID == newParent.identifier {
                Log.warning("moveAndRenameWithUniqueSuffix received with unchanged parent — applying rename only", domain: .fileProvider)
                _ = try await tower.rename(node: nodeIdentifier, cleartextName: newItem.filename, mimeType: item.contentType?.preferredMIMEType, moc: moc)
            } else {
                _ = try await tower.move(
                    nodeID: nodeIdentifier,
                    under: newParent,
                    withNewName: newItem.filename,
                    moc: moc
                )
            }

            return newItem
        }
    }

}
