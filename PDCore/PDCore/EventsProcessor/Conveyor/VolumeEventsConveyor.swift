// Copyright (c) 2024 Proton AG
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
/// Is using volumeId to filter only relevant events
final class VolumeEventsConveyor: EventsConveyor {
    internal let persistentQueue: EventStorageManager
    private var referenceStorage: VolumeEventsReferenceStorageProtocol
    private lazy var controller = persistentQueue.queue(volumeId: volumeId)
    private var entriesToProcess = [EventStorageManager.Entry]()
    private let serializer: GenericEventSerializer
    private let volumeId: String

    init(storage: EventStorageManager, referenceStorage: VolumeEventsReferenceStorageProtocol, serializer: GenericEventSerializer, volumeId: String) {
        self.persistentQueue = storage
        self.referenceStorage = referenceStorage
        self.serializer = serializer
        self.volumeId = volumeId
    }

    func prepareForProcessing() {
        try? self.controller.performFetch()
        self.entriesToProcess = self.controller.fetchedObjects as! [EventStorageManager.Entry]
    }

    func next() -> EventPack? {
        guard !self.entriesToProcess.isEmpty else {
            return nil
        }

        let next = self.entriesToProcess.removeFirst()
        return self.makeEventPack(from: next)
    }

    func disregard(_ id: NSManagedObjectID) {
        self.persistentQueue.disregard(id)
    }

    func completeProcessing(of id: NSManagedObjectID) {
        self.persistentQueue.discard(id)
    }

    func clearUp() {
        self.persistentQueue.clearUp(volumeId: volumeId)
    }

    func record(_ events: [GenericEvent]) {
        persistentQueue.persist(
            events: zip(events, events.compactMap { try? serializer.serialize(event: $0) }),
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
        guard let event = try? serializer.deserialize(data: data) else {
            assert(false, "Failed to unpack Event contents")
            return nil
        }

        return (event, shareId, objectID)
    }

    func hasUnprocessedEvents() -> Bool {
        do {
            return try self.persistentQueue.unprocessedEventCount(volumeId: volumeId) > 0
        } catch {
            return false
        }
    }
}

extension VolumeEventsConveyor {
    enum Errors: Error {
        case lostEventsDuringConversion
    }

    /// Latest event that's been both used to update the metadata DB and enumerated
    func lastFullyHandledEvent() -> GenericEvent? {
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

    func lastEventAwaitingEnumeration() -> GenericEvent? {
        lastEvent(awaitingEnumerationOnly: true)
    }

    func lastReceivedEvent() -> GenericEvent? {
        lastEvent(awaitingEnumerationOnly: false)
    }

    private func lastEvent(awaitingEnumerationOnly: Bool) -> GenericEvent? {
        do {
            guard let entry = try self.persistentQueue.lastEvent(awaitingEnumerationOnly: awaitingEnumerationOnly, volumeId: volumeId),
                  let pack = makeEventPack(from: entry) else {
                return nil
            }
            return pack.event
        } catch {
            assert(false, error.localizedDescription)
            return nil
        }
    }

    func history(since anchor: EventID?) throws -> [EventPack] {
        let persistedEvents = try self.persistentQueue.eventsAwaitingEnumeration(since: anchor, volumeId: volumeId)
        let events = persistedEvents.compactMap(makeEventPack)
        guard events.count == persistedEvents.count else {
            throw Errors.lostEventsDuringConversion
        }
        return events
    }

    func setEnumerated(_ objectIDs: [NSManagedObjectID]) {
        self.persistentQueue.setEnumerated(objectIDs)
    }

    // MARK: Reference data accessors

    var latestEventFetchTime: Date? {
        get { referenceStorage.getLatestEventFetchTime(volumeId: volumeId) }
        set { referenceStorage.setLatestEventFetchTime(date: newValue, volumeId: volumeId) }
    }

    var latestFetchedEventID: EventID? {
        get { referenceStorage.getLatestFetchedEventID(volumeId: volumeId) }
        set { referenceStorage.setLatestFetchedEventID(eventID: newValue, volumeId: volumeId) }
    }

    var referenceDate: Date? {
        get { referenceStorage.getReferenceDate(volumeId: volumeId) }
        set { referenceStorage.setReferenceDate(date: newValue, volumeId: volumeId) }
    }

    var referenceID: EventID? {
        get { referenceStorage.getReferenceID(volumeId: volumeId) }
        set { referenceStorage.setReferenceID(eventID: newValue, volumeId: volumeId) }
    }
}
