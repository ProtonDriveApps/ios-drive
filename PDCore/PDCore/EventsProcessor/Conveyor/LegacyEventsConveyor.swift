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
public final class LegacyEventsConveyor: EventsConveyor {
    private static let serializer = ClientEventSerializer()
    // Legacy events system is used with unmigrated data - DB nodes have volumeId empty.
    private let volumeId = ""

    internal let persistentQueue: EventStorageManager
    private var referenceStorage: LegacyEventsReferenceStorageProtocol
    private lazy var controller = self.persistentQueue.queue(volumeId: volumeId)
    private var entriesToProcess = [EventStorageManager.Entry]()

    public init(storage: EventStorageManager, referenceStorage: LegacyEventsReferenceStorageProtocol) {
        self.persistentQueue = storage
        self.referenceStorage = referenceStorage
    }
    
    public func prepareForProcessing() {
        try? self.controller.performFetch()
        self.entriesToProcess = self.controller.fetchedObjects as! [EventStorageManager.Entry]
    }
    
    public func next() -> EventPack? {
        guard !self.entriesToProcess.isEmpty else {
            return nil
        }
        
        let next = self.entriesToProcess.removeFirst()
        return self.makeEventPack(from: next)
    }
    
    public func disregard(_ id: NSManagedObjectID) {
        self.persistentQueue.disregard(id)
    }
    
    public func completeProcessing(of id: NSManagedObjectID) {
        self.persistentQueue.discard(id)
    }
    
    public func clearUp() {
        self.persistentQueue.clearUp(volumeId: volumeId)
    }

    public func record(_ events: [GenericEvent]) {
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
        try? serializer.serialize(event: genericEvent)
    }
    
    static func unpack(_ package: Data) -> GenericEvent? {
        try? serializer.deserialize(data: package)
    }
    
    public func hasUnprocessedEvents() -> Bool {
        do {
            return try self.persistentQueue.unprocessedEventCount(volumeId: volumeId) > 0
        } catch {
            return false
        }
    }
}

extension LegacyEventsConveyor {
    enum Errors: Error {
        case lostEventsDuringConversion
    }

    /// Latest event that's been both used to update the metadata DB and enumerated
    public func lastFullyHandledEvent() -> GenericEvent? {
        do {
            guard let entry = try self.persistentQueue.lastFullyHandledEvent(volumeId: volumeId),
                  let pack = makeEventPack(from: entry) else {
                return nil
            }
            return pack.event
        } catch let error {
            assert(false, error.localizedDescription)
            return nil
        }
    }
    
    public func lastEventAwaitingEnumeration() -> GenericEvent? {
        lastEvent(awaitingEnumerationOnly: true)
    }

    public func lastReceivedEvent() -> GenericEvent? {
        lastEvent(awaitingEnumerationOnly: false)
    }

    private func lastEvent(awaitingEnumerationOnly: Bool) -> GenericEvent? {
        do {
            guard let entry = try self.persistentQueue.lastEvent(awaitingEnumerationOnly: awaitingEnumerationOnly, volumeId: volumeId),
                  let pack = makeEventPack(from: entry) else {
                return nil
            }
            return pack.event
        } catch let error {
            assert(false, error.localizedDescription)
            return nil
        }
    }
    
    public func history(since anchor: EventID?) throws -> [EventPack] {
        let persistedEvents = try self.persistentQueue.eventsAwaitingEnumeration(since: anchor, volumeId: volumeId)
        let events = persistedEvents.compactMap(self.makeEventPack)
        guard events.count == persistedEvents.count else {
            throw Errors.lostEventsDuringConversion
        }
        return events
    }
    
    public func setEnumerated(_ objectIDs: [NSManagedObjectID]) {
        self.persistentQueue.setEnumerated(objectIDs)
    }

    // MARK: Reference data accessors

    public var latestEventFetchTime: Date? {
        get { referenceStorage.latestEventFetchTime }
        set { referenceStorage.latestEventFetchTime = newValue }
    }

    public var latestFetchedEventID: EventID? {
        get { referenceStorage.latestFetchedEventID }
        set { referenceStorage.latestFetchedEventID = newValue }
    }

    public var referenceDate: Date? {
        get { referenceStorage.referenceDate }
        set { referenceStorage.referenceDate = newValue }
    }

    public var referenceID: EventID? {
        get { referenceStorage.referenceID }
        set { referenceStorage.referenceID = newValue }
    }
}
