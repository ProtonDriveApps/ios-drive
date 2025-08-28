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

public protocol LegacyEventsReferenceStorageProtocol {
    var latestEventFetchTime: Date? { get set }
    var latestFetchedEventID: EventID? { get set }
    var referenceDate: Date? { get set }
    var referenceID: EventID? { get set }
}

public final class LegacyEventsReferenceStorage: LegacyEventsReferenceStorageProtocol {
    @SettingsStorage("EventsConveyor.latestEventFetchTime") public var latestEventFetchTime: Date?
    @SettingsStorage("EventsConveyor.latestFetchedEventID") public var latestFetchedEventID: EventID?
    @SettingsStorage("EventsConveyor.referenceDate") public var referenceDate: Date?
    @SettingsStorage("EventsConveyor.referenceID") public var referenceID: EventID?

    // Only needed for migration to shared AppGroud UserDefaults
    @FastStorage("lastEventFetchTime-Cloud") private var legacyLastEventFetchTime: Date?
    @FastStorage("lastKnownEventID-Cloud") private var legacyLastScannedEventID: EventID?
    @FastStorage("referenceDate-Cloud") private var legacyReferenceDate: Date?

    public init(suite: SettingsStorageSuite) {
        self._latestEventFetchTime.configure(with: suite)
        self._latestFetchedEventID.configure(with: suite)
        self._referenceDate.configure(with: suite)
        self._referenceID.configure(with: suite)

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
}
