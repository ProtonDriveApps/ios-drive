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

import os.log
import Foundation
import CoreData
import PDClient

final class DriveEventsLoopProcessor: LogObject {
    static let osLog: OSLog = OSLog(subsystem: "PDCore", category: "DriveEventsLoopProcessor")
    
    private let cloudSlot: CloudSlot
    private let conveyor: EventsConveyor
    private let storage: StorageManager
    
    internal init(cloudSlot: CloudSlot, conveyor: EventsConveyor, storage: StorageManager) {
        self.cloudSlot = cloudSlot
        self.conveyor = conveyor
        self.storage = storage
    }
    
    private var moc: NSManagedObjectContext {
        // should be a dedicated background context to exclude deadlock by CloudSlot operations
        storage.eventsContext
    }
    
    func process() throws -> [NodeIdentifier] {
        var affectedNodes: [NodeIdentifier] = []
        
        try moc.performAndWait {
            try applyEventsToStorage(&affectedNodes)
            
            if moc.hasChanges {
                try moc.save()
            }
        }
        
        ConsoleLogger.shared?.log("Finished processing events for \(affectedNodes.count) nodes", osLogType: Self.self)
        return affectedNodes
    }
    
    private func applyEventsToStorage(_ affectedNodes: inout [NodeIdentifier]) throws {

        while let (event, shareID, objectID) = conveyor.next() {
            let nodeID = event.inLaneNodeId
            let parentID = event.inLaneParentId
            
            ConsoleLogger.shared?.log("Process event `\(event.genericType)`. Node id: \(nodeID) parent id: \(parentID ?? "-")", osLogType: Self.self)

            switch event.genericType {
            case .create where nodeExists(id: parentID): // need to know parent
                let updated = update(shareId: shareID, from: event)
                affectedNodes.append(contentsOf: updated)

            case .updateMetadata where nodeExists(id: parentID) || nodeExists(id: nodeID): // need to know node (move from) or the new parent (move to)
                let updated = update(shareId: shareID, from: event)
                affectedNodes.append(contentsOf: updated)

            case [.delete, .updateContent] where nodeExists(id: nodeID):  // need to know node
                let updated = update(shareId: shareID, from: event)
                affectedNodes.append(contentsOf: updated)

            default: // ignore event
                ConsoleLogger.shared?.log("Ignore event because it is not relevant for current metadata", osLogType: Self.self)
                ignored(event: event, storage: storage)
            }

            ConsoleLogger.shared?.log("Done processing event, now removing it", osLogType: Self.self)
            conveyor.completeProcessing(of: objectID)
        }
        
    }
    
}

extension DriveEventsLoopProcessor {
    
    private func update(shareId: String, from event: GenericEvent) -> [NodeIdentifier] {
        let nodeID = event.inLaneNodeId
        guard let event = event as? Event else {
            assert(false, "Wrong event type sent to \(#file)")
            return []
        }
        
        switch event.eventType {
        case .delete:
            guard let node = findNode(id: nodeID) else {
                return []
            }
            moc.delete(node)
            return [node.identifier, node.parentLink?.identifier].compactMap { $0 }
            
        case .create, .updateMetadata:
            let nodes = cloudSlot.update([event.link], of: shareId, in: moc)
            nodes.forEach { node in
                guard let parent = node.parentLink else { return }
                node.isInheritingOfflineAvailable = parent.isInheritingOfflineAvailable || parent.isMarkedOfflineAvailable
            }
            var affectedNodes = nodes.compactMap(\.parentLink).map(\.identifier)
            affectedNodes.append(contentsOf: nodes.map(\.identifier))
            return affectedNodes
            
        case .updateContent:
            guard let file: File = storage.existing(with: [nodeID], in: moc).first else {
                return []
            }
            if let revision = file.activeRevision {
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
    
    private func findNode(id: String, by attribute: String = "id") -> Node? {
        let asFile: File? = storage.existing(with: [id], by: attribute, in: moc).first
        let asFolder: Folder? = storage.existing(with: [id], by: attribute, in: moc).first
        return asFolder ?? asFile
    }
    
    private func nodeExists(id: String?) -> Bool {
        guard let id = id else { return false }
        return self.storage.exists(with: id, in: moc)
    }
    
}
