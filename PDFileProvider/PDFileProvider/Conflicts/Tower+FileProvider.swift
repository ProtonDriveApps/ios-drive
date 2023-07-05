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

    func retrieveSiblings(of itemTemplate: NSFileProviderItem) throws -> [Node] {
        guard let shareID = self.node(itemIdentifier: itemTemplate.parentItemIdentifier)?.shareID,
              let parentID = nodeIdentifier(for: itemTemplate.parentItemIdentifier) else {
            return []
        }

        let siblingsAndSelf = try storage.fetchChildren(of: parentID.nodeID, share: shareID, sorting: .default, moc: storage.mainContext)
        let siblings = siblingsAndSelf.filter { child in
            child.identifier != nodeIdentifier(for: itemTemplate.itemIdentifier)
            && child.localID != itemTemplate.itemIdentifier.rawValue
        }
        return siblings
    }

    func rootFolder() throws -> Folder {
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
        return fileSystemSlot?.getDraft(item.itemIdentifier.rawValue, shareID: parent.shareID) as? File
    }

}
