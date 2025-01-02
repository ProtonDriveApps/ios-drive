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

protocol VolumeEventsReferenceStorageProtocol {
    func getLatestEventFetchTime(volumeId: String) -> Date?
    func setLatestEventFetchTime(date: Date?, volumeId: String)
    func getLatestFetchedEventID(volumeId: String) -> EventID?
    func setLatestFetchedEventID(eventID: EventID?, volumeId: String)
    func getReferenceDate(volumeId: String) -> Date?
    func setReferenceDate(date: Date?, volumeId: String)
    func getReferenceID(volumeId: String) -> EventID?
    func setReferenceID(eventID: EventID?, volumeId: String)
}

final class VolumeEventsReferenceStorage: VolumeEventsReferenceStorageProtocol {
    typealias VolumeId = String

    private var legacyStorage: LegacyEventsReferenceStorageProtocol
    private let queue = DispatchQueue(label: "EventsReferenceStorage", qos: .default)

    @SettingsCodableProperty("EventsReferenceStorage.latestEventFetchTimes") private var latestEventFetchTimes: [VolumeId: Date] = [:]
    @SettingsCodableProperty("EventsReferenceStorage.latestFetchedEventIDs") private var latestFetchedEventIDs: [VolumeId: EventID] = [:]
    @SettingsCodableProperty("EventsReferenceStorage.referenceDates") private var referenceDates: [VolumeId: Date] = [:]
    @SettingsCodableProperty("EventsReferenceStorage.referenceIDs") private var referenceIDs: [VolumeId: EventID] = [:]

    init(legacyStorage: LegacyEventsReferenceStorageProtocol, suite: SettingsStorageSuite, mainVolumeId: String) {
        self.legacyStorage = legacyStorage
        
        self._latestEventFetchTimes.configure(with: suite)
        self._latestFetchedEventIDs.configure(with: suite)
        self._referenceDates.configure(with: suite)
        self._referenceIDs.configure(with: suite)

        migrateFromLegacyStorage(mainVolumeId: mainVolumeId)
    }

    private func migrateFromLegacyStorage(mainVolumeId: String) {
        if let latestEventFetchTime = legacyStorage.latestEventFetchTime, latestEventFetchTimes.isEmpty {
            latestEventFetchTimes = [mainVolumeId: latestEventFetchTime]
            legacyStorage.latestEventFetchTime = nil
        }
        if let latestFetchedEventID = legacyStorage.latestFetchedEventID, latestFetchedEventIDs.isEmpty {
            latestFetchedEventIDs = [mainVolumeId: latestFetchedEventID]
            legacyStorage.latestFetchedEventID = nil
        }
        if let referenceDate = legacyStorage.referenceDate, referenceDates.isEmpty {
            referenceDates = [mainVolumeId: referenceDate]
            legacyStorage.referenceDate = nil
        }
        if let referenceID = legacyStorage.referenceID, referenceIDs.isEmpty {
            referenceIDs = [mainVolumeId: referenceID]
            legacyStorage.referenceID = nil
        }
    }

    func getLatestEventFetchTime(volumeId: String) -> Date? {
        queue.sync {
            latestEventFetchTimes[volumeId]
        }
    }

    func setLatestEventFetchTime(date: Date?, volumeId: String) {
        queue.sync {
            latestEventFetchTimes[volumeId] = date
        }
    }

    func getLatestFetchedEventID(volumeId: String) -> EventID? {
        queue.sync {
            latestFetchedEventIDs[volumeId]
        }
    }

    func setLatestFetchedEventID(eventID: EventID?, volumeId: String) {
        queue.sync {
            latestFetchedEventIDs[volumeId] = eventID
        }
    }

    func getReferenceDate(volumeId: String) -> Date? {
        queue.sync {
            referenceDates[volumeId]
        }
    }

    func setReferenceDate(date: Date?, volumeId: String) {
        queue.sync {
            referenceDates[volumeId] = date
        }
    }

    func getReferenceID(volumeId: String) -> EventID? {
        queue.sync {
            return referenceIDs[volumeId]
        }
    }

    func setReferenceID(eventID: EventID?, volumeId: String) {
        queue.sync {
            referenceIDs[volumeId] = eventID
        }
    }
}
