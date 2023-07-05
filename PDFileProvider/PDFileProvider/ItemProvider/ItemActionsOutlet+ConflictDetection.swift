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

extension ItemActionsOutlet: ConflictDetection {

    // Return values: (detectedConflict: ConflictingOperation?, remoteVersion: Node?)
    public func identifyConflict(
        tower: Tower,
        basedOn item: NSFileProviderItem,
        changeType: ItemActionChangeType,
        fields: NSFileProviderItemFields) -> (ResolutionAction, Node?)? {

            switch changeType {
            case .create:
                return conflictOnCreate(tower: tower, item: item, fields: fields)
                
            case .move(let version):
                // parent changed
                return conflictOnMove(tower: tower, item: item, baseVersion: version, fields: fields)
                
            case .modifyMetadata(let version):
                // + renamed
                return conflictOnMetadata(tower: tower, item: item, baseVersion: version, fields: fields)
                
            case .modifyContents(let version, let contentsURL):
                return conflictOnContents(tower: tower, item: item, baseVersion: version, fields: fields, contents: contentsURL)
            
            case .delete(version: let version):
                return conflictOnDelete(tower: tower, item: item, baseVersion: version)
            }
    }

    private func conflictOnCreate(tower: Tower, item: NSFileProviderItem, fields: NSFileProviderItemFields) -> (ResolutionAction, Node?)? {
        guard tower.parentFolder(of: item) != nil else {
            return (.createWithUniqueSuffixInConflictsFolder, nil)
        }

        let siblings = try? tower.retrieveSiblings(of: item)

        if let sibling = siblings?.first(where: {
            return $0.decryptedName == item.filename
        }) {
            if item.isFolder {
                if sibling is Folder { // Folder-Folder -> pseudo
                    return (.ignore, sibling)
                } else { // Folder-File
                    return (.createWithUniqueSuffix, sibling)
                }
            } else { // File-File or File-Folder
                return (.createWithUniqueSuffix, sibling)
            }
        }

        return nil
    }

    private func conflictOnMove(tower: Tower,
                                item: NSFileProviderItem,
                                baseVersion version: NSFileProviderItemVersion,
                                fields: NSFileProviderItemFields) -> (ResolutionAction, Node?)? {
        // Move-Move/Rename/Create (Destination) - different node IDs but same parent and same name
        let siblings = try? tower.retrieveSiblings(of: item)
        if let conflictingSibling = siblings?.first(where: { sibling in
            item.filename == sibling.decryptedName
        }) {
            return (.moveAndRenameWithUniqueSuffix, conflictingSibling)
        }

        // Move-ParentDelete (Destination)
        guard tower.parentFolder(of: item) != nil else {
            return (.ignore, nil)
        }

        // Move-Delete
        guard let remoteNode = tower.node(itemIdentifier: item.itemIdentifier) else {
            // The remote version may have been trashed or definitely deleted
            return (.recreate, nil)
        }

        // Move-Move (Source) - same node ID but different parent
        let oldItemsParentIdentiferHash = MetadataVersion(from: version.metadataVersion)?.parentIdentifierHash
        let remoteNodesParentIdentiferHash = ItemVersionHasher.hash(for: NodeItem(node: remoteNode).parentItemIdentifier)
        if NodeIdentifier(item.parentItemIdentifier) != remoteNode.parentLink?.identifier,
           oldItemsParentIdentiferHash != remoteNodesParentIdentiferHash {
            return (.ignore, remoteNode)
        }

        // Move-Move (Pseudo) - everything's the same
        if NodeIdentifier(item.parentItemIdentifier) == remoteNode.parentLink?.identifier {
            return (.ignore, remoteNode)
        }
        
        // Move-Move (Cycle) - one of the new parent's ancestors is self
        var remoteAncestor: Node? = tower.node(itemIdentifier: item.parentItemIdentifier)
        while remoteAncestor?.parentLink != nil {
            guard let parentIdentifier = remoteAncestor?.parentLink?.identifier else {
                break
            }
            
            if NodeIdentifier(item.itemIdentifier) == remoteAncestor?.parentLink?.identifier {
                return (.ignore, remoteNode)
            }
            
            remoteAncestor = tower.node(itemIdentifier: NSFileProviderItemIdentifier(parentIdentifier))
        }

        return nil
    }

    private func conflictOnMetadata(tower: Tower,
                                    item: NSFileProviderItem,
                                    baseVersion version: NSFileProviderItemVersion,
                                    fields: NSFileProviderItemFields) -> (ResolutionAction, Node?)? {
        if fields.contains(.filename) {
            // Rename-Rename/Move/Create (Destination) - different node IDs but same parent and same name
            let siblings = try? tower.retrieveSiblings(of: item)
            if let conflictingSibling = siblings?.first(where: { sibling in
                item.filename == sibling.decryptedName
            }) {
                return (.renameWithUniqueSuffix, conflictingSibling)
            }

            // Rename-ParentDelete
            guard tower.parentFolder(of: item) != nil else {
                return (.createWithUniqueSuffixInConflictsFolder, nil)
            }

            // Rename-Delete
            guard let remoteNode = tower.node(itemIdentifier: item.itemIdentifier) else {
                // The remote version may have been trashed or definitely deleted
                return (.recreate, nil)
            }

            // Rename-Rename (Source) - same node ID but different name
            let oldItemsFilenameHash = MetadataVersion(from: version.metadataVersion)?.filenameHash
            let remoteNodesFilenameHash = ItemVersionHasher.hash(for: remoteNode.decryptedName)
            if item.filename != remoteNode.decryptedName,
               oldItemsFilenameHash != remoteNodesFilenameHash {
                return (.ignore, remoteNode)
            }

            // Rename-Rename (Pseudo) - everything's the same
            if item.filename == remoteNode.decryptedName {
                return (.ignore, remoteNode)
            }

            return nil
        }

        return nil
    }

    private func conflictOnContents(
        tower: Tower,
        item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        fields: NSFileProviderItemFields,
        contents newContent: URL?
    ) -> (ResolutionAction, Node?)? {
        // Edit-ParentDelete
        guard tower.parentFolder(of: item) != nil else {
            // parent node has been deleted remotely
            return (.createWithUniqueSuffixInConflictsFolder, nil)
        }
        
        // Edit-Delete
        guard let remoteNode = tower.node(itemIdentifier: item.itemIdentifier) else {
            // file has been deleted remotely
            return (.recreate, nil)
        }
        
        // Important: `item` always has a blank contentVersion because FileProvider does not know how to calculate it
        // So here we are comparing baseVersion to one in local DB:
        // - we had some revision locally before file was edited -> left hand value
        // - event system would update/nullify activeRevision if remote edits it -> right hand value
        // Edit-Edit
        if version.contentVersion != ContentVersion(node: remoteNode).encoded() {
            return (.createWithUniqueSuffix, nil)
        }

        return nil
    }

    private func conflictOnDelete(tower: Tower, item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion) -> (ResolutionAction, Node?)? {
        guard let node = tower.node(itemIdentifier: item.itemIdentifier) else {
            // node was already deleted
            return (.ignore, nil)
        }
        
        guard version == NodeItem(node: node).itemVersion else {
            // node was somehow modified (either metadata or content)
            return (.ignore, nil)
        }
        
        return nil
    }
}
