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

import Foundation
import CoreData
import PDClient

protocol DriveEventsLoopProcessorType {
    func process() throws -> [NodeIdentifier]
}

final class DriveEventsLoopProcessor: DriveEventsLoopProcessorType {
    
    private let cloudSlot: CloudSlotProtocol
    private let conveyor: EventsConveyor
    private let storage: StorageManager
    
    internal init(cloudSlot: CloudSlotProtocol, conveyor: EventsConveyor, storage: StorageManager) {
        self.cloudSlot = cloudSlot
        self.conveyor = conveyor
        self.storage = storage
    }

    // Should be a dedicated background context to exclude deadlock by CloudSlot operations
    // Each processor owns a separate context. The assumption is that all the metadata DB Nodes are separate between
    // the volumes. There is no CoreData relationship between any node in one volume and a node in another volume,
    // so there's no need to use a single context for multiple loops / processors.
    private lazy var moc: NSManagedObjectContext = storage.newBackgroundContext()
    
    func process() throws -> [NodeIdentifier] {
        var affectedNodes: [NodeIdentifier] = []
        
        try moc.performAndWait {
            try applyEventsToStorage(&affectedNodes)
            
            if moc.hasChanges {
                try moc.saveOrRollback()
            }
        }
        
        Log.info("Finished processing events for \(affectedNodes.count) nodes", domain: .events)
        return affectedNodes
    }
    
    private func applyEventsToStorage(_ affectedNodes: inout [NodeIdentifier]) throws {

        while let (event, shareID, objectID) = conveyor.next() {
            guard let event = event as? Event else {
                Log.info("Ignore event because it is not relevant for current metadata", domain: .events)
                ignored(event: event, storage: storage)
                Log.info("Done processing event, now removing it", domain: .events)
                conveyor.completeProcessing(of: objectID)
                continue
            }

            let nodeID = event.inLaneNodeId
            let volumeID = event.link.volumeID
            let nodeIdentifier = NodeIdentifier(nodeID, shareID, volumeID)
            let parentIdentifier = makeNodeIdentifier(volumeID: volumeID, shareID: shareID, nodeID: event.inLaneParentId)

            Log.info("Process event `\(event.genericType)`. Node: \(nodeIdentifier), Parent: \(String(describing: parentIdentifier))", domain: .events)

            switch event.genericType {
            case .create where !nodeExists(id: nodeIdentifier) && nodeExists(id: parentIdentifier): // need to know parent
                let updated = update(shareId: shareID, from: event)
                affectedNodes.append(contentsOf: updated)
                
            case .create where nodeExists(id: nodeIdentifier):
                conveyor.disregard(objectID)

            case .updateMetadata where nodeExists(id: parentIdentifier) || nodeExists(id: nodeIdentifier): // need to know node (move from) or the new parent (move to)
                let updated = update(shareId: shareID, from: event)
                affectedNodes.append(contentsOf: updated)

            case [.delete, .updateContent] where nodeExists(id: nodeIdentifier):  // need to know node
                let updated = update(shareId: shareID, from: event)
                affectedNodes.append(contentsOf: updated)

            default: // ignore event
                Log.info("Ignore event because it is not relevant for current metadata", domain: .events)
                ignored(event: event, storage: storage)
            }

            Log.info("Done processing event, now removing it", domain: .events)
            conveyor.completeProcessing(of: objectID)
        }
    }
}

extension DriveEventsLoopProcessor {

    private func makeNodeIdentifier(volumeID: String, shareID: String, nodeID: String?) -> NodeIdentifier? {
        guard let nodeID else { return nil }
        return NodeIdentifier(nodeID, shareID, volumeID)
    }

    private func update(shareId: String, from event: GenericEvent) -> [NodeIdentifier] {
        guard let event = event as? Event else {
            assert(false, "Wrong event type sent to \(#file)")
            return []
        }
        
        switch event.eventType {
        case .delete:
            let identifier = NodeIdentifier(event.link.linkID, shareId, event.link.volumeID)
            guard let node = findNode(id: identifier) else {
                return []
            }
            moc.delete(node)
            return [node.identifier, node.parentLink?.identifier].compactMap { $0 }
            
        case .create, .updateMetadata:
            let nodes = cloudSlot.update([event.link], of: shareId, in: moc)
            nodes.forEach { node in
                guard let parent = node.parentLink else { return }
                node.setIsInheritingOfflineAvailable(parent.isInheritingOfflineAvailable || parent.isMarkedOfflineAvailable)
            }
            var affectedNodes = nodes.compactMap(\.parentLink).map(\.identifier)
            affectedNodes.append(contentsOf: nodes.map(\.identifier))
            return affectedNodes
            
        case .updateContent:
            let identifier = NodeIdentifier(event.link.linkID, shareId, event.link.volumeID)
            guard let file = findFile(identifier: identifier) else {
                return []
            }
            if let revision = file.activeRevision, revision.id != event.link.fileProperties?.activeRevision?.ID {
                storage.removeOldBlocks(of: revision)
                file.activeRevision = nil
            }
            return [file.identifier]
        }
    }
    
    private func ignored(event: GenericEvent, storage: StorageManager) {
        // link may be shared or unshared - need to re-fetch Share URLs
        storage.finishedFetchingShareURLs = false
        
        // link may be trashed or untrashed - need to re-fetch Trash
        storage.finishedFetchingTrash = false
    }
}

extension DriveEventsLoopProcessor {
    private func findNode(id identifier: NodeIdentifier, by attribute: String = "id") -> Node? {
        if identifier.volumeID.isEmpty {
            let asFile: File? = storage.existing(with: [identifier.nodeID], by: attribute, allowSubclasses: true, in: moc).first
            let asFolder: Folder? = storage.existing(with: [identifier.nodeID], by: attribute, in: moc).first
            return asFolder ?? asFile
        } else {
            let asFile = File.fetch(identifier: identifier, allowSubclasses: true, in: moc)
            let asFolder = Folder.fetch(identifier: identifier, in: moc)
            return asFolder ?? asFile
        }
    }
    
    private func nodeExists(id identifier: NodeIdentifier?) -> Bool {
        guard let identifier = identifier else { return false }
        if identifier.volumeID.isEmpty {
            return self.storage.exists(with: identifier.nodeID, in: moc)
        } else {
            return Node.fetch(identifier: identifier, allowSubclasses: true, in: moc) != nil
        }
    }
    
    private func findFile(identifier: NodeIdentifier) -> File? {
        if identifier.volumeID.isEmpty {
            let file: File? = storage.existing(with: [identifier.nodeID], in: moc).first
            return file
        } else {
            let file = File.fetch(identifier: identifier, allowSubclasses: true, in: moc)
            return file
        }
    }
}
