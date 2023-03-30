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
import PMEventsManager
import ProtonCore_Services

extension Tower {
    static func makeDriveEventsSystem(storage: StorageManager, eventStorage: EventStorageManager, appGroup: SettingsStorageSuite, eventObservers: [EventsListener], eventProviders: [EventsProvider], processLocally: Bool) -> (EventsConveyor, EventsProcessor) {
        let eventsConveyor = EventsConveyor(storage: eventStorage)
        
        let eventProcessor = EventsProcessor(
            storage: storage,
            eventsConveyor: eventsConveyor,
            observers: eventObservers,
            observedLanes: eventProviders,
            processLocally: processLocally
        )
        
        return (eventsConveyor, eventProcessor)
    }
    
    static func makeCoreEventsSystem(appGroup: SettingsStorageSuite, sessionVault: SessionVault, generalSettings: GeneralSettings, paymentsSecureStorage: PaymentsSecureStorage, network: PMAPIService) -> CoreEventLoopManager {
        let processor = GeneralEventsLoopProcessor(sessionVault: sessionVault, generalSettings: generalSettings, paymentsVault: paymentsSecureStorage)
        
        let generalEventsLoop = GeneralEventsLoop(
            apiService: network,
            processor: processor,
            userDefaults: appGroup.userDefaults,
            logError: {
                ConsoleLogger.shared?.log($0, osLogType: Tower.self)
            }
        )
        
        let coreEventManager = CoreEventLoopManager(
            generalLoop: generalEventsLoop,
            refillPeriod: EventsProcessor.refillInterval
        )
        
        return coreEventManager
    }
    
    /// Start polling from current local state.
    /// Some polling systems will fetch initial event ID, some require it to exist.
    func startEventsPolling(shareId: EventStorageManager.ShareID) {
        self.eventProcessor.start(for: shareId)
        self.coreEventManager.start()
    }
    
    /// Stop active polling and clears local storages used by the polling system.
    /// After calling this method polling needs to be re-started from scratch including fetch of initial event ID.
    func discardEventsPolling() {
        eventProcessor.discard()
        
        coreEventManager.suspend()
        coreEventManager.destroyAnchors()
        coreEventManager.reset()
    }
    
    /// Pause active polling, does not affect local storages.
    func pauseEventsPolling() {
        self.eventProcessor.stopTimer()
        self.coreEventManager.suspend()
    }
}
