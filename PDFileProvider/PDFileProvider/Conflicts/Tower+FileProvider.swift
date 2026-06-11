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
import PDCore
import FileProvider

extension Tower {

    func nodeWithName(of item: NSFileProviderItem, moc: NSManagedObjectContext) async throws -> Node? {
        guard let parent = await self.node(itemIdentifier: item.parentItemIdentifier, in: moc) as? Folder else {
            throw Errors.parentNotFound(identifier: item.parentItemIdentifier)
        }

        return try moc.performAndWait {
            let hash = try NameHasher.hash(item.filename, parent: parent)
            let clientUID = sessionVault.getUploadClientUID()
            return (try storage.fetchChildrenUploadedByClientsOtherThan(clientUID,
                                                                        with: hash,
                                                                        of: parent.id,
                                                                        share: parent.shareId,
                                                                        moc: moc)).first
        }
    }

    public func rootFolder(moc: NSManagedObjectContext) async throws -> Folder {
        guard let root = await node(itemIdentifier: .rootContainer, in: moc) as? Folder else {
            assertionFailure("Could not find rootContainer")
            throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: .rootContainer)
        }
        return root
    }

    func nodeIdentifier(for itemIdentifier: NSFileProviderItemIdentifier, moc: NSManagedObjectContext) -> NodeIdentifier? {
        guard itemIdentifier != .workingSet, itemIdentifier != .trashContainer else {
            return nil
        }
        guard itemIdentifier != .rootContainer else {
            return rootFolderIdentifier(moc: moc)
        }
        return NodeIdentifier(itemIdentifier)
    }

    public func parentFolder(of item: NSFileProviderItem, in moc: NSManagedObjectContext) async -> Folder? {
        await node(itemIdentifier: item.parentItemIdentifier, in: moc) as? Folder
    }

    public func node(itemIdentifier: NSFileProviderItemIdentifier, in moc: NSManagedObjectContext) async -> Node? {
        guard let nodeIdentifier = self.nodeIdentifier(for: itemIdentifier, moc: moc) else {
            return nil
        }

        /// Try fetching local node first...
        let localNode = fileSystemSlot?.getNode(nodeIdentifier, moc: moc)

        /// If found, return it...
        if let localNode {
            return localNode
        }

        /// ...otherwise fetch the remote node and return it.
        do {
            let remoteNode = try await cloudSlot.scanNode(
                nodeIdentifier, linkProcessingErrorTransformer: { $1 }, moc: moc
            )
            return remoteNode
        } catch {
            Log.error("Could not fetch node from API", domain: .clientNetworking, context: LogContext("nodeIdentifier: \(nodeIdentifier)"))
            return nil
        }
    }

    func draft(for item: NSFileProviderItem, moc: NSManagedObjectContext) async -> File? {
        guard let parent = await parentFolder(of: item, in: moc) else {
            return nil
        }

        return moc.performAndWait {
            return fileSystemSlot?.getDraft(item.itemIdentifier.rawValue, shareID: parent.shareId, moc: moc) as? File
        }
    }

}
