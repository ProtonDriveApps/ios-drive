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

import CoreData
import Foundation
import PDCore
import PDClient

final class EventsBootstrapStarter: AppBootstrapper {
    private let eventsStarter: EventsSystemStarter
    private let mainVolumeIdDataSource: MainVolumeIdDataSourceProtocol
    private let eventsStorageManager: EventStorageManager
    private let eventsManagedObjectContext: NSManagedObjectContext
    private let eventSerializer: GenericEventSerializer

    init(eventsStarter: EventsSystemStarter, mainVolumeIdDataSource: MainVolumeIdDataSourceProtocol, eventsStorageManager: EventStorageManager, eventsManagedObjectContext: NSManagedObjectContext, eventSerializer: GenericEventSerializer) {
        self.mainVolumeIdDataSource = mainVolumeIdDataSource
        self.eventsStarter = eventsStarter
        self.eventsStorageManager = eventsStorageManager
        self.eventsManagedObjectContext = eventsManagedObjectContext
        self.eventSerializer = eventSerializer
    }

    func bootstrap() async throws {
        try await migrateStoredEventsIfNecessary()
        eventsStarter.startEventsSystem()
    }

    private func migrateStoredEventsIfNecessary() async throws {
        let events = try await eventsStorageManager.fetchUnprocessedEvents(volumeId: "", managedObjectContext: eventsManagedObjectContext)
        guard !events.isEmpty else {
            return
        }

        do {
            let volumeId = try await mainVolumeIdDataSource.getMainVolumeId()
            try await migrateVolumelessEvents(events: events, volumeId: volumeId)
        } catch {
            Log.error("Events migration to volume based failed: \(error.localizedDescription)", domain: .events)
            throw error
        }
    }

    private func migrateVolumelessEvents(events: [PersistedEvent], volumeId: String) async throws {
        try await eventsManagedObjectContext.perform {
            try events.forEach { event in
                try self.migrate(event: event, volumeId: volumeId)
            }
            try self.eventsManagedObjectContext.saveOrRollback()
        }
    }

    private func migrate(event: PersistedEvent, volumeId: String) throws {
        event.volumeId = volumeId

        guard let contents = event.contents else {
            return
        }

        if var deserializedEvent = try? eventSerializer.deserialize(data: contents) as? PDClient.Event {
            deserializedEvent.link = Link(link: deserializedEvent.link, volumeID: volumeId)
            event.contents = try eventSerializer.serialize(event: deserializedEvent)
        }
    }
}
