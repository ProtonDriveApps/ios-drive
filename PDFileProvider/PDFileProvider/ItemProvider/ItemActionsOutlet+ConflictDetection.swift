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

#if os(OSX)
extension ItemActionsOutlet: ConflictDetection {

    /// Return values: (detectedConflict: ConflictingOperation?, remoteVersion: Node?)
    /// Throws if conflict should be resolved by the system
    public func identifyConflict(tower: Tower,
                                 basedOn item: NSFileProviderItem,
                                 changeType: ItemActionChangeType,
                                 fields: NSFileProviderItemFields) throws -> (ResolutionAction, Node?)? {

        switch changeType {
        case .create:
            return try conflictOnCreate(tower: tower, item: item, fields: fields)

        case .move(let version):
            // parent changed
            return try conflictOnMove(tower: tower, item: item, baseVersion: version, fields: fields)

        case .modifyMetadata(let version):
            // + renamed
            return try conflictOnMetadata(tower: tower, item: item, baseVersion: version, fields: fields)

        case .modifyContents(let version, let contentsURL):
            return try conflictOnContents(tower: tower, item: item, baseVersion: version, fields: fields, contents: contentsURL)

        case .trash(version: let version), .delete(version: let version):
            return try conflictOnDelete(tower: tower, item: item, baseVersion: version)
        }
    }

    private func conflictOnCreate(tower: Tower, item: NSFileProviderItem, fields: NSFileProviderItemFields) throws -> (ResolutionAction, Node?)? {
        // Create-ParentDelete
        guard let parent = tower.parentFolder(of: item) else {
            throw Errors.conflictIdentified(reason: "Trying to create item, but parent not found")
        }

        // Create-ParentTrash
        // Only the top most trashed ancestor is marked as deleted, so we must search the tree to identify this conflict
        guard !ancestorInTrash(startingParent: parent) else {
            // ancestor node has been trashed remotely
            throw Errors.conflictIdentified(reason: "Trying to create item, but parent in trash")
        }

        // Create-Create/Rename/Move (Destination) - name conflict
        if let conflictingNode = try tower.nodeWithName(of: item) {
            if item.isFolder && conflictingNode is Folder { // Folder-Folder -> pseudo
                return (.ignore, conflictingNode)
            } else { // File-File, File-Folder or Folder-File
                return (.createWithUniqueSuffix, conflictingNode)
            }
        }

        return nil
    }

    private func conflictOnMove(tower: Tower,
                                item: NSFileProviderItem,
                                baseVersion version: NSFileProviderItemVersion,
                                fields: NSFileProviderItemFields) throws -> (ResolutionAction, Node?)? {
        // Move-ParentDelete (Destination)
        guard let parent = tower.parentFolder(of: item) else {
            return (.ignore, nil)
        }

        // Move-ParentTrash (Destination)
        // Only the top most trashed ancestor is marked as deleted, so we must search the tree to identify this conflict
        guard !ancestorInTrash(startingParent: parent) else {
            // ancestor node has been trashed remotely
            return (.ignore, nil)
        }

        if let conflictingNode = try tower.nodeWithName(of: item) {
            return conflictingNode.moc?.performAndWait {
                if conflictingNode.identifier == tower.nodeIdentifier(for: item.itemIdentifier) {
                    // Move-Move (Pseudo) - everything's the same
                    return (.ignore, conflictingNode)
                } else {
                    // Move-Move/Rename/Create (Destination) - name conflict, different node IDs but same parent and same name
                    return (.moveAndRenameWithUniqueSuffix, conflictingNode)
                }
            }
        }

        // Move-Delete
        guard let remoteNode = tower.node(itemIdentifier: item.itemIdentifier) else {
            // The remote version may have been deleted
            return (.recreate, nil)
        }

        var remoteNodeState: Node.State!
        var remoteNodeParentIdentifier: NodeIdentifier?
        remoteNode.moc!.performAndWait {
            remoteNodeState = remoteNode.state
            remoteNodeParentIdentifier = remoteNode.parentLink?.identifier
        }

        // Move-Trash
        guard remoteNodeState != .deleted else {
            // The remote version has been trashed
            return (.recreate, nil)
        }

        // Move-Move (Source) - same node ID but different parent
        
        let oldItemsParentIdentiferHash = MetadataVersion(from: version.metadataVersion)?.parentIdentifierHash
        do {
            let remoteItem = try NodeItem(node: remoteNode)
            let remoteNodesParentIdentiferHash = ItemVersionHasher.hash(for: remoteItem.parentItemIdentifier)
            // If the metadata version is beforeFirstSyncComponent, it means the system has not yet
            // assigned the proper version to the item (even though we had returned the item with the version).
            // The system is sometimes slow on it. Se we cannot compare the local hash with the remote hash
            // because there is no local hash yet.
            if version.metadataVersion != NSFileProviderItemVersion.beforeFirstSyncComponent,
               NodeIdentifier(item.parentItemIdentifier) != remoteNodeParentIdentifier,
               oldItemsParentIdentiferHash != remoteNodesParentIdentiferHash {
                return (.ignore, remoteNode)
            }
        } catch {
            Log.error("Move-Move (Source) check chouldn't be made due to inability to generate NodeItem: \(error)", domain: .fileProvider)
        }

        // Move-Move (Cycle) - one of the new parent's ancestors is self
        var remoteAncestor: Node? = tower.node(itemIdentifier: item.parentItemIdentifier)
        var remoteAncestorParentIdentifier: NodeIdentifier? = remoteAncestor?.moc?.performAndWait { remoteAncestor?.parentLink?.identifier }
        while let parentIdentifier = remoteAncestorParentIdentifier {
            if NodeIdentifier(item.itemIdentifier) == parentIdentifier {
                return (.ignore, remoteNode)
            }
            
            remoteAncestor = tower.node(itemIdentifier: NSFileProviderItemIdentifier(parentIdentifier))
            remoteAncestorParentIdentifier = remoteAncestor?.moc?.performAndWait { remoteAncestor?.parentLink?.identifier }
        }

        return nil
    }

    private func conflictOnMetadata(tower: Tower,
                                    item: NSFileProviderItem,
                                    baseVersion version: NSFileProviderItemVersion,
                                    fields: NSFileProviderItemFields) throws -> (ResolutionAction, Node?)? {
        if fields.contains(.filename) {
            // Rename-ParentDelete
            guard let parent = tower.parentFolder(of: item) else {
                throw Errors.conflictIdentified(reason: "Trying to rename item, but parent not found")
            }

            // Rename-ParentTrash
            // Only the top most trashed ancestor is marked as deleted, so we must search the tree to identify this conflict
            guard !ancestorInTrash(startingParent: parent) else {
                // ancestor node has been trashed remotely
                throw Errors.conflictIdentified(reason: "Trying to rename item, but parent in trash")
            }

            if let conflictingNode = try tower.nodeWithName(of: item) {
                return conflictingNode.moc?.performAndWait {
                    if conflictingNode.identifier == tower.nodeIdentifier(for: item.itemIdentifier) {
                        // Rename-Rename (Pseudo) - everything's the same
                        return (.ignore, conflictingNode)
                    } else {
                        // Rename-Rename/Move/Create (Destination) - name conflict - different node IDs but same parent and same name
                        return (.renameWithUniqueSuffix, conflictingNode)
                    }
                }
            }

            // Rename-Delete
            guard let remoteNode = tower.node(itemIdentifier: item.itemIdentifier) else {
                // The remote version may have been deleted
                return (.recreate, nil)
            }

            // Rename-Trash
            var remoteNodeState: Node.State!
            remoteNode.moc!.performAndWait {
                remoteNodeState = remoteNode.state
            }
            guard remoteNodeState != .deleted else {
                // The remote version has been trashed
                return (.recreate, nil)
            }
            
            // Rename-Rename (Source) - same node ID but different name
            let oldItemsFilenameHash = MetadataVersion(from: version.metadataVersion)?.filenameHash
            var remoteName: String!
            try remoteNode.moc!.performAndWait {
                remoteName = try remoteNode.decryptName()
            }
            let remoteNodesFilenameHash = ItemVersionHasher.hash(for: remoteName)
            
            // If the metadata version is beforeFirstSyncComponent, it means the system has not yet
            // assigned the proper version to the item (even though we had returned the item with the version).
            // Se we cannot compare the local hash with the remote hash because there is no local hash yet.
            // One scenario where this sometimes happen: create folder and assign it a name.
            // We first get create callback with "untitled folder" name and then modify callback
            // with rename to a proper name. But the modify callback might not yet contain the version
            // of the item we returned from the create file. The system is sometimes slow in that regard.
            if version.metadataVersion != NSFileProviderItemVersion.beforeFirstSyncComponent,
               item.filename != remoteName,
               oldItemsFilenameHash != remoteNodesFilenameHash {
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
    ) throws -> (ResolutionAction, Node?)? {
        // Edit-ParentDelete
        guard let parent = tower.parentFolder(of: item) else {
            // parent node has been deleted remotely
            throw Errors.conflictIdentified(reason: "Trying to edit file, but parent not found")
        }

        // Edit-ParentTrash
        // Only the top most trashed ancestor is marked as deleted, so we must search the tree to identify this conflict
        guard !ancestorInTrash(startingParent: parent) else {
            // ancestor node has been trashed remotely
            throw Errors.conflictIdentified(reason: "Trying to edit file, but parent in trash")
        }
        
        // Edit-Delete
        guard let remoteNode = tower.node(itemIdentifier: item.itemIdentifier) else {
            // file has been deleted remotely
            return (.recreate, nil)
        }

        // Edit-ProtonDoc
        guard let mimeType = remoteNode.moc?.performAndWait({ remoteNode.mimeType }),
              MimeType(value: mimeType) != .protonDocument else {
            // the Drive API doesn't support new revisions of Proton Doc files
            // (the Docs API must be used for this purpose if our native clients
            // ever support Proton Doc editing in the future)
            return (.ignore, remoteNode)
        }

        var remoteNodeState: Node.State!
        var remoteContentVersion: Data!
        remoteNode.moc!.performAndWait {
            remoteNodeState = remoteNode.state
            remoteContentVersion = ContentVersion(node: remoteNode).encoded()
        }

        // Edit-Trash
        guard remoteNodeState != .deleted else {
            // file has been trashed remotely
            return (.recreate, nil)
        }
        
        // Important: `item` always has a blank contentVersion because FileProvider does not know how to calculate it
        // So here we are comparing baseVersion to one in local DB:
        // - we had some revision locally before file was edited -> left hand value
        // - event system would update/nullify activeRevision if remote edits it -> right hand value
        // Edit-Edit
        if version.contentVersion != remoteContentVersion {
            return (.createWithUniqueSuffix, nil)
        }

        return nil
    }

    private func conflictOnDelete(tower: Tower, item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion) throws -> (ResolutionAction, Node?)? {
        guard let node = tower.node(itemIdentifier: item.itemIdentifier) else {
            // node already deleted
            return (.ignore, nil)
        }

        let (state, isTrashInheriting) = node.moc!.performAndWait {
            return (node.state, node.isTrashInheriting)
        }
        
        guard state != .deleted && !isTrashInheriting else {
            // node already trashed
            return (.ignore, nil)
        }

        // Versions are not consistent in working reliably on macOS 14+
//        guard version == NodeItem(node: node).itemVersion || version.metadataVersion == NSFileProviderItemVersion.beforeFirstSyncComponent else {
//            // node was somehow modified (either metadata or content)
//            return (.ignore, nil)
//        }

        return nil
    }

    private func ancestorInTrash(startingParent parent: Folder) -> Bool {
        var ancestor: Folder = parent
        return ancestor.moc?.performAndWait {
            while let nextAncestor = ancestor.parentLink {
                guard ancestor.state != .deleted else {
                    return true
                }

                ancestor = nextAncestor
            }

            return false
        } ?? false
    }
}
#endif
