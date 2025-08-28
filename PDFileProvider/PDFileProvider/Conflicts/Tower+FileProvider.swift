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

    func nodeWithName(of item: NSFileProviderItem) async throws -> Node? {
        guard let parent = await self.node(itemIdentifier: item.parentItemIdentifier) as? Folder,
              let moc = parent.moc else {
            throw Errors.parentNotFound
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

    public func rootFolder() async throws -> Folder {
        guard let root = await node(itemIdentifier: .rootContainer) as? Folder else {
            assertionFailure("Could not find rootContainer")
            throw NSFileProviderError(.noSuchItem)
        }
        return root
    }

    func nodeIdentifier(for itemIdentifier: NSFileProviderItemIdentifier) -> NodeIdentifier? {
        guard itemIdentifier != .workingSet, itemIdentifier != .trashContainer else {
            return nil
        }
        guard itemIdentifier != .rootContainer else {
            return rootFolderIdentifier()
        }
        return NodeIdentifier(itemIdentifier)
    }

    public func parentFolder(of item: NSFileProviderItem) async -> Folder? {
        await node(itemIdentifier: item.parentItemIdentifier) as? Folder
    }

    public func node(itemIdentifier: NSFileProviderItemIdentifier) async -> Node? {
        guard let nodeIdentifier = self.nodeIdentifier(for: itemIdentifier) else {
            return nil
        }

        /// Try fetching local node first...
        let localNode = fileSystemSlot?.getNode(nodeIdentifier)

        /// If found, return it...
        if let localNode {
            return localNode
        }

        /// ...otherwise fetch the remote node and return it.
        do {
            let remoteNode = try await cloudSlot.scanNode(nodeIdentifier) { $1 }
            return remoteNode
        } catch {
            Log.error("Could not fetch node from API", domain: .clientNetworking, context: LogContext("nodeIdentifier: \(nodeIdentifier)"))
            return nil
        }
    }

    func draft(for item: NSFileProviderItem) async -> File? {
        guard let parent = await parentFolder(of: item) else {
            return nil
        }

        guard let moc = parent.moc else {
            Log.error("Attempting to fetch identifier when moc is nil (node has been deleted)", error: nil, domain: .fileProvider)
            fatalError()
        }

        return moc.performAndWait {
            return fileSystemSlot?.getDraft(item.itemIdentifier.rawValue, shareID: parent.shareId) as? File
        }
    }

}
