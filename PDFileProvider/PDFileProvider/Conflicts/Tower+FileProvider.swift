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

    func nodeWithName(of item: NSFileProviderItem) throws -> Node? {
        guard let parent = self.node(itemIdentifier: item.parentItemIdentifier) as? Folder,
              let moc = parent.moc else {
            throw Errors.parentNotFound
        }

        return try moc.performAndWait {
            let hash = try NameHasher.hash(item.filename, parent: parent)
            let clientUID = sessionVault.getUploadClientUID()
            return (try storage.fetchChildrenUploadedByClientsOtherThan(clientUID,
                                                                        with: hash,
                                                                        of: parent.id,
                                                                        share: parent.shareID,
                                                                        moc: moc)).first
        }
    }

    public func rootFolder() throws -> Folder {
        guard let root = node(itemIdentifier: .rootContainer) as? Folder else {
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

    func parentFolder(of item: NSFileProviderItem) -> Folder? {
        node(itemIdentifier: item.parentItemIdentifier) as? Folder
    }

    func node(itemIdentifier: NSFileProviderItemIdentifier) -> Node? {
        guard let nodeIdentifier = self.nodeIdentifier(for: itemIdentifier) else {
            return nil
        }
        return fileSystemSlot?.getNode(nodeIdentifier)
    }
    
    func draft(for item: NSFileProviderItem) -> File? {
        guard let parent = parentFolder(of: item) else {
            return nil
        }

        guard let moc = parent.moc else {
            Log.error("Attempting to fetch identifier when moc is nil (node has been deleted)", domain: .fileProvider)
            fatalError()
        }

        return moc.performAndWait {
            return fileSystemSlot?.getDraft(item.itemIdentifier.rawValue, shareID: parent.shareID) as? File
        }
    }

}
