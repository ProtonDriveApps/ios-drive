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
import PDCore

actor SyncStatusUpdater {

    @SettingsStorage(UserDefaults.Key.lastSyncedTimeKey.rawValue)
    private(set) var lastSyncedTime: TimeInterval?

    #if DEBUG
    @SettingsStorage(UserDefaults.NotificationPropertyKeys.syncingKey.rawValue, additionalLogging: true)
    private(set) var syncing: Bool?
    #else
    @SettingsStorage(UserDefaults.NotificationPropertyKeys.syncingKey.rawValue)
    private(set) var syncing: Bool?
    #endif
    
    private let instanceIdentifier = UUID()

    init() {
        Log.info("SyncStatusUpdater init: \(instanceIdentifier.uuidString)", domain: .syncing)
        let suite = SettingsStorageSuite.group(named: Constants.appGroup)
        _lastSyncedTime.configure(with: suite)
        _syncing.configure(with: suite)
    }
    
    deinit {
        Log.info("SyncStatusUpdater deinit: \(instanceIdentifier.uuidString)", domain: .syncing)
    }

    func updateTime(with newValue: TimeInterval) {
        Log.debug("SyncStatusUpdater \(instanceIdentifier.uuidString) Last Synced Date: \(newValue)", domain: .syncing)
        self.lastSyncedTime = newValue
    }

    func updateSyncing(with newValue: Bool) {
        Log.info("SyncStatusUpdater \(instanceIdentifier.uuidString) Syncing: \(newValue)", domain: .syncing)
        // we can clear the old value before writing a new one just to ensure the value is propagated to the observers
        // the observers are only geeting notified on the value change, but we want to ensure they will be notified every time
        self.syncing = nil
        self.syncing = newValue
    }

}
