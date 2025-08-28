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
import FileProvider

protocol DriveEventsLoopProcessorType {
    func process() throws -> [NodeIdentifier]
}

final class DriveEventsLoopProcessor: DriveEventsLoopProcessorType {
    
    private let cloudSlot: CloudSlotProtocol
    private let conveyor: EventsConveyor
    private let storage: StorageManager
    private let externalInvitationConverter: ExternalInvitationConvertProtocol?

    internal init(
        cloudSlot: CloudSlotProtocol,
        conveyor: EventsConveyor,
        storage: StorageManager,
        externalInvitationConverter: ExternalInvitationConvertProtocol?
    ) {
        self.cloudSlot = cloudSlot
        self.conveyor = conveyor
        self.storage = storage
        self.externalInvitationConverter = externalInvitationConverter
    }

    // Should be a dedicated background context to exclude deadlock by CloudSlot operations
    // Each processor owns a separate context. The assumption is that all the metadata DB Nodes are separate between
    // the volumes. There is no CoreData relationship between any node in one volume and a node in another volume,
    // so there's no need to use a single context for multiple loops / processors.
    private lazy var moc: NSManagedObjectContext = storage.eventsBackgroundContext

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
        
        func updateMetadata(_ shareID: String, _ event: Event) {
            let updated = self.update(shareId: shareID, from: event)
            affectedNodes.append(contentsOf: updated)
        }

        while let (event, shareID, objectID) = conveyor.next() {
            Log.debug("Start to handle event \(event.eventId)", domain: .events)
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

            var linkType: String = "Unknown"
            switch event.link.type {
            case .file:
                if event.link.fileProperties?.activeRevision?.photo == nil {
                    linkType = "File"
                } else {
                    linkType = "Photo"
                }
            default:
                linkType = event.link.type.desc
            }

            switch event.genericType {
            case .create:
                // case 1. — node already exists in the DB
                if let node = findNode(id: nodeIdentifier) {
                    let state = moc.performAndWait { node.state }
                    if event.link.state.rawValue == state?.rawValue {
                        // Fix for DM-387 & DM-398
                        Log.info("Process .create event. Disregard due to \(linkType): \(nodeIdentifier.any()) with the same state already in the metadataDB", domain: .events)
                        conveyor.disregard(objectID)
                    } else {
                        Log.info("Process .create event. \(linkType): \(nodeIdentifier.any()) already exists but state is different update metadata", domain: .events)
                        updateMetadata(shareID, event)
                    }
                    
                // case 2. — node doesn't yet exists in the DB, but its parent exists, so we can create the node
                } else if nodeExists(id: parentIdentifier) {
                    Log.info("Process .create event. \(linkType): \(nodeIdentifier.any()) doesn't exist but parent exists, create it", domain: .events)
                    updateMetadata(shareID, event)
                
                // case 3. — neither node nor parent exists, let's ignore
                } else {
                    Log.info("Process .create event. Ignore \(linkType): \(nodeIdentifier.any()) because neither parent nor node exists", domain: .events)
                    ignored(event: event, storage: storage)
                }

            case .updateMetadata where nodeExists(id: parentIdentifier) || nodeExists(id: nodeIdentifier), // need to know node (move from) or the new parent (move to)
                 .delete,
                 .updateContent where nodeExists(id: nodeIdentifier): // need to know node
                Log.info("Process \(event.genericType). Update metadata for \(linkType): \(nodeIdentifier.any())", domain: .events)
                updateMetadata(shareID, event)

            default: // ignore event
                Log.info("Ignore \(event.genericType) event for \(linkType): \(nodeIdentifier.any()), parent \(parentIdentifier) because it is not relevant for current metadata", domain: .events)
                ignored(event: event, storage: storage)
            }

            Log.info("Done processing event for node: \(nodeIdentifier.any()), now removing it", domain: .events)
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
        let identifier = NodeIdentifier(event.link.linkID, shareId, event.link.volumeID)

        switch event.eventType {
        case .delete:
            guard let node = findNode(id: identifier) else {
                Log.info("Processing delete event. Node: \(identifier.any()) not found", domain: .events)
                return []
            }
            moc.delete(node)
            return [node.identifier, node.parentNode?.identifier].compactMap { $0 }
            
        case .create, .updateMetadata:
            let nodes = cloudSlot.update([event.link], of: shareId, in: moc)

            #if os(iOS)
            nodes.forEach { node in
                guard let parent = node.parentNode else {
                    Log.info("Processing \(event.eventType) event. Parent node not found for \(identifier.any())", domain: .events)
                    return
                }
                node.setIsInheritingOfflineAvailable(parent.isInheritingOfflineAvailable || parent.isMarkedOfflineAvailable)
            }
            processEventData(event: event)
            #endif

            var affectedNodes = nodes.compactMap(\.parentLink).map(\.identifier)
            affectedNodes.append(contentsOf: nodes.map(\.identifier))
            return affectedNodes
            
        case .updateContent:
            let identifier = NodeIdentifier(event.link.linkID, shareId, event.link.volumeID)
            guard let file = findFile(identifier: identifier) else {
                Log.info("Processing .updateContent event. File: \(identifier.any()) not found", domain: .events)
                return []
            }
            if let revision = file.activeRevision, revision.id != event.link.fileProperties?.activeRevision?.ID {
                revision.removeOldThumbnails(in: moc)
                storage.removeOldBlocks(of: revision)
                file.activeRevision = nil
                _ = cloudSlot.update([event.link], of: shareId, in: moc)
                removeCachedFileForFileProvider(file: file)
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

    private func processEventData(event: Event) {
        guard let data = event.data else { return }
        if let externalInvitationSignup = data.externalInvitationSignup,
           let shareID = event.link.sharingDetails?.shareID {
            Task {
                do {
                    try await externalInvitationConverter?.execute(
                        parameters: .init(shareID: shareID, externalInvitationID: externalInvitationSignup)
                    )
                } catch {
                    Log.error("Failed to convert external invitation to internal", error: error, domain: .sharing)
                }
            }
        }
    }
}

extension DriveEventsLoopProcessor {
    private func findNode(id identifier: NodeIdentifier, by attribute: String = "id") -> Node? {
        if identifier.volumeID.isEmpty {
            let asFile: File? = storage.existing(with: [identifier.nodeID], by: attribute, allowSubclasses: true, in: moc).first
            let asFolder: Folder? = storage.existing(with: [identifier.nodeID], by: attribute, in: moc).first
            let asAlbum: CoreDataAlbum? = storage.existing(with: [identifier.nodeID], by: attribute, in: moc).first
            return asFolder ?? asFile ?? asAlbum
        } else {
            let asFile = File.fetch(identifier: identifier, allowSubclasses: true, in: moc)
            let asFolder = Folder.fetch(identifier: identifier, in: moc)
            let asAlbum = CoreDataAlbum.fetch(identifier: identifier, in: moc)
            return asFolder ?? asFile ?? asAlbum
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

    private func findAlbum(identifier: NodeIdentifier) -> CoreDataAlbum? {
        CoreDataAlbum.fetch(identifier: identifier, in: moc)
    }

    /// When accessing a file through a file provider, it serves the cached version instead of downloading the latest data.
    /// Remove cached file to make sure user can see correct data
    private func removeCachedFileForFileProvider(file: File) {
        #if os(iOS)
        let nodeIdentifier = file.identifier

        guard let filename = try? file.decryptName() else {
            Log.debug("Skip removing cached file for FileProvider because decryptName failed", domain: .events)
            return
        }

        var url = NSFileProviderManager.default.documentStorageURL
        url.appendPathComponent(nodeIdentifier.shareID, isDirectory: true)
        url.appendPathComponent(nodeIdentifier.nodeID, isDirectory: true)
        url.appendPathComponent(filename, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Log.debug(
                "Failed to delete cache file for ***.\(url.pathExtension), error: \(error.localizedDescription)",
                domain: .events
            )
        }
        #endif
    }
}
