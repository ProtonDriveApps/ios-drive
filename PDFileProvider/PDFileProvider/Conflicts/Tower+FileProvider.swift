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

    func retrieveNodes(basedOn itemTemplate: NSFileProviderItem) -> [Node] {
        guard let shareID = self.node(itemIdentifier: itemTemplate.parentItemIdentifier)?.shareID else {
            return []
        }

        return storage.fetchNodes(of: shareID, moc: storage.mainContext)
    }

    func nodeIdentifier(for itemIdentifier: NSFileProviderItemIdentifier) -> NodeIdentifier? {
        guard itemIdentifier != .workingSet, itemIdentifier != .trashContainer else {
            return nil
        }
        guard itemIdentifier != .rootContainer else {
            return rootFolder()
        }
        return NodeIdentifier(itemIdentifier)
    }

    func parentFolder(of item: NSFileProviderItem) -> Folder? {
        node(itemIdentifier: item.parentItemIdentifier) as? Folder
    }

    func node(itemIdentifier: NSFileProviderItemIdentifier) -> Node? {
        guard let parentIdentifier = self.nodeIdentifier(for: itemIdentifier) else {
            return nil
        }
        return fileSystemSlot?.getNode(parentIdentifier)
    }

}
