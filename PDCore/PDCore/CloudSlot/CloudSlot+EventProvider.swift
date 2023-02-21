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

private typealias Event = PDClient.Event

extension CloudSlot: EventsProvider {
    
    func convert(_ inLaneNodeID: String?, storage: StorageManager, moc: NSManagedObjectContext) -> String? {
        return inLaneNodeID
    }
    
    func clearUp() {
        self.lastScannedEventID = nil
        self.lastEventFetchTime = nil
        self.referenceDate = nil
    }
    
    func moveLastScannedEventID(after eventsPack: ScanEventsResult) {
        self.lastScannedEventID = eventsPack.latestEventID
    }
    
    func scanEventsFromRemote(of shareID: String, handler: @escaping ScanEventsHandler) {
        guard let lastKnown = self.lastScannedEventID else {
            ConsoleLogger.shared?.log("No latest event recorded, getting one from server", osLogType: Self.self)
            self.client.getLatestEvent(shareID) { [weak self] result in
                switch result {
                case .success(let eventID):
                    self?.referenceDate = Date()
                    self?.lastScannedEventID = eventID
                    self?.lastEventFetchTime = Date()
                    handler(.success(.init(latestEventID: eventID, events: [], more: false)))
                case .failure(let error):
                    handler(.failure(error))
                }
            }
            return
        }
        
        self.client.getEvents(shareID, since: lastKnown) { (result: Result<(EventID, [Event], MoreEvents), Error>) in
            switch result {
            case let .success((eventID, events, more)):
                self.lastEventFetchTime = Date()
                let scanned = ScanEventsResult(latestEventID: eventID, events: events, more: more)
                handler(.success(scanned))
            case let .failure(error):
                handler(.failure(error))
            }
        }
    }
    
    func update(shareId: String, from event: GenericEvent, storage: StorageManager, moc: NSManagedObjectContext) -> [NodeIdentifier] {
        guard let universalNodeID = self.convert(event.inLaneNodeId, storage: storage, moc: moc) else {
            assert(false, "Could not find metadata for event with in-lane id \(event.inLaneNodeId)")
            return []
        }
        guard let event = event as? Event else {
            assert(false, "Wrong event type sent to \(#file)")
            return []
        }
        
        switch event.eventType {
        case .delete:
            guard let node = self.findNode(id: universalNodeID, storage: storage, moc: moc) else {
                return []
            }
            moc.delete(node)
            return [node.identifier, node.parentLink?.identifier].compactMap { $0 }
            
        case .create, .updateMetadata:
            let nodes = self.update([event.link], of: shareId, in: moc)
            nodes.forEach { node in
                guard let parent = node.parentLink else { return }
                node.isInheritingOfflineAvailable = parent.isInheritingOfflineAvailable || parent.isMarkedOfflineAvailable
            }
            var affectedNodes = nodes.compactMap(\.parentLink).map(\.identifier)
            affectedNodes.append(contentsOf: nodes.map(\.identifier))
            return affectedNodes

        case .updateContent:
            guard let file: File = storage.existing(with: [universalNodeID], in: moc).first else {
                return []
            }
            if let revision = file.activeRevision {
                storage.removeOldBlocks(of: revision)
                file.activeRevision = nil
            }
            return [file.identifier]
        }
    }
    
    func ignored(event: GenericEvent, storage: StorageManager, moc: NSManagedObjectContext) {
        // link may be shared or unshared - need to re-fetch Share URLs
        storage.finishedFetchingShareURLs = false
        
        // link may be trashed or untrashed - need to re-fetch Trash
        storage.finishedFetchingTrash = false
    }
    
    static func pack(_ genericEvent: GenericEvent) -> Data? {
        guard let event = genericEvent as? Event else {
            assert(false, "Wrong event type sent to \(#file)")
            return nil
        }
        
        return try? JSONEncoder().encode(event)
    }
    
    static func unpack(_ package: Data) -> GenericEvent? {
        guard let event = try? JSONDecoder().decode(Event.self, from: package) else {
            assert(false, "Wrong event type sent to \(#file)")
            return nil
        }
        return event
    }
}
