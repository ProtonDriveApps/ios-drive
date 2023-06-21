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

/// Accepts unordered events from different sources and returns in a chronological order
final class EventsConveyor: NSObject {
    typealias HistoryRow = (event: GenericEvent, share: String)
    typealias EventPack = (event: GenericEvent, share: String, objectID: NSManagedObjectID)
    
    internal let persistentQueue: EventStorageManager
    private lazy var controller = self.persistentQueue.queue()
    private var entriesToProcess = [EventStorageManager.Entry]()
    
    init(storage: EventStorageManager) {
        self.persistentQueue = storage
    }
    
    func prepareForProcessing() {
        try? self.controller.performFetch()
        self.entriesToProcess = self.controller.fetchedObjects as! [EventStorageManager.Entry]
    }

    func eventsAreReady() -> Bool {
        return !self.entriesToProcess.isEmpty
    }
    
    func next() -> EventPack? {
        guard !self.entriesToProcess.isEmpty else {
            return nil
        }
        
        let next = self.entriesToProcess.removeFirst()
        return self.makeEventPack(from: next)
    }
    
    func completeProcessing(of id: NSManagedObjectID) {
        self.persistentQueue.discard(id)
    }
    
    func clearUp() {
        self.persistentQueue.clearUp()
    }
    
    func record(_ events: [GenericEvent]) {
        persistentQueue.persist(
            events: zip(events, events.compactMap(Self.pack)),
            provider: String(describing: CloudSlot.self)
        )
    }
    
    private func makeEventPack(from next: EventStorageManager.Entry) -> EventPack? {
        guard let objectID = next[#keyPath(PersistedEvent.objectID)] as? NSManagedObjectID,
              let shareId = next[#keyPath(PersistedEvent.shareId)] as? String,
              let data = next[#keyPath(PersistedEvent.contents)] as? Data else
        {
            assert(false, "Broken EventStorageManager.Entry")
            return nil
        }
        guard let event = Self.unpack(data) else {
            assert(false, "Failed to unpack Event contents")
            return nil
        }
        
        return (event, shareId, objectID)
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

extension EventsConveyor {
    enum Errors: Error {
        case lostEventsDuringConversion
    }
    
    func lastProcessedEvent() -> GenericEvent? {
        lastEvent(onlyProcessed: true)
    }

    func lastReceivedEvent() -> GenericEvent? {
        lastEvent(onlyProcessed: false)
    }

    private func lastEvent(onlyProcessed: Bool) -> GenericEvent? {
        do {
            guard let entry = try self.persistentQueue.lastEvent(onlyProcessed: onlyProcessed),
                  let pack = makeEventPack(from: entry) else
            {
                return nil
            }
            return pack.event
        } catch let error {
            assert(false, error.localizedDescription)
            return nil
        }
    }
    
    func history(since anchor: EventID?) throws -> [HistoryRow] {
        let persistedEvents = try self.persistentQueue.events(since: anchor)
        let events = persistedEvents.compactMap(self.makeEventPack).map { ($0.event, $0.share) }
        guard events.count == persistedEvents.count else {
            throw Errors.lostEventsDuringConversion
        }
        return events
    }
}
