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
class EventsConveyor: NSObject {
    typealias EventPack = (event: GenericEvent, share: String, objectID: NSManagedObjectID)
    
    @SettingsStorage("EventsConveyor.latestEventFetchTime") var latestEventFetchTime: Date?
    @SettingsStorage("EventsConveyor.latestFetchedEventID") var latestFetchedEventID: EventID?
    @SettingsStorage("EventsConveyor.referenceDate") var referenceDate: Date?
    @SettingsStorage("EventsConveyor.referenceID") var referenceID: EventID?
    
    // Only needed for migration to shared AppGroud UserDefaults
    @FastStorage("lastEventFetchTime-Cloud") private var legacyLastEventFetchTime: Date?
    @FastStorage("lastKnownEventID-Cloud") private var legacyLastScannedEventID: EventID?
    @FastStorage("referenceDate-Cloud") private var legacyReferenceDate: Date?
    
    internal let persistentQueue: EventStorageManager
    private lazy var controller = self.persistentQueue.queue()
    private var entriesToProcess = [EventStorageManager.Entry]()
    
    init(storage: EventStorageManager, suite: SettingsStorageSuite) {
        self.persistentQueue = storage
        
        self._latestEventFetchTime.configure(with: suite)
        self._latestFetchedEventID.configure(with: suite)
        self._referenceDate.configure(with: suite)
        self._referenceID.configure(with: suite)
        
        super.init()
        
        migrationFromCloudSlot()
    }
    
    // These values were previously stored in app's UserDefaults and accessors were implemented in `CloudSlot`
    // This method moved legacy values from app's UserDefaults to the app group's UserDefaults
    private func migrationFromCloudSlot() {
        if legacyLastEventFetchTime != nil, latestEventFetchTime == nil {
            latestEventFetchTime = legacyLastEventFetchTime
            legacyLastEventFetchTime = nil
        }
        if legacyLastScannedEventID != nil, latestFetchedEventID == nil {
            latestFetchedEventID = legacyLastScannedEventID
            referenceID = legacyLastScannedEventID
            legacyLastScannedEventID = nil
        }
        if legacyReferenceDate != nil, referenceDate == nil {
            referenceDate = legacyReferenceDate
            legacyReferenceDate = nil
        }
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
    
    func hasUnprocessedEvents() -> Bool {
        do {
            return try self.persistentQueue.unprocessedEventCount() > 0
        } catch {
            return false
        }
    }
}

extension EventsConveyor {
    enum Errors: Error {
        case lostEventsDuringConversion
    }

    /// Latest event that's been both used to update the metadata DB and enumerated
    func lastFullyHandledEvent() -> GenericEvent? {
        do {
            guard let entry = try self.persistentQueue.lastFullyHandledEvent(),
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
    
    func lastEventAwaitingEnumeration() -> GenericEvent? {
        lastEvent(awaitingEnumerationOnly: true)
    }

    func lastReceivedEvent() -> GenericEvent? {
        lastEvent(awaitingEnumerationOnly: false)
    }

    private func lastEvent(awaitingEnumerationOnly: Bool) -> GenericEvent? {
        do {
            guard let entry = try self.persistentQueue.lastEvent(awaitingEnumerationOnly: awaitingEnumerationOnly),
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
    
    func history(since anchor: EventID?) throws -> [EventPack] {
        let persistedEvents = try self.persistentQueue.eventsAwaitingEnumeration(since: anchor)
        let events = persistedEvents.compactMap(self.makeEventPack)
        guard events.count == persistedEvents.count else {
            throw Errors.lostEventsDuringConversion
        }
        return events
    }
    
    func setEnumerated(_ objectIDs: [NSManagedObjectID]) {
        self.persistentQueue.setEnumerated(objectIDs)
    }
}
