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

public protocol EventsSystemManager {
    typealias EventsHistoryRow = (event: GenericEvent, share: String)
    
    // event scheduler
    func intializeEventsSystem()
    func runEventsSystem()
    func pauseEventsSystem()
    
    // event loops
    func forceProcessEvents()
    var eventProcessorIsRunning: Bool { get }
    
    // conveyor
    func lastProcessedEvent() -> GenericEvent?
    func lastReceivedEvent() -> GenericEvent?
    func eventsHistory(since anchor: EventID?) throws -> [EventsHistoryRow]
}

extension Tower: EventsSystemManager {
    
    public func intializeEventsSystem() {
        let moc = self.storage.backgroundContext
        moc.performAndWait {
            let addressIDs = self.sessionVault.addressIDs
            let processor = DriveEventsLoopProcessor(cloudSlot: cloudSlot, conveyor: eventsConveyor, storage: storage)
            
            if let mainShare = self.storage.mainShareOfVolume(by: addressIDs, moc: moc),
               let volumeID = mainShare.volume?.id
            {
                let logError: DriveEventsLoop.LogHandler = {
                    ConsoleLogger.shared?.log($0, osLogType: Tower.self)
                }
                let loop = DriveEventsLoop(volumeID: volumeID, cloudSlot: self.cloudSlot, processor: processor, conveyor: self.eventsConveyor, observers: self.eventObservers, mode: self.eventProcessingMode, logError: logError)
                
                coreEventManager.enable(loop: loop, for: volumeID)
            }
        }
    }
    
    public func runEventsSystem() {
        coreEventManager.start()
    }
    
    public var eventProcessorIsRunning: Bool {
        coreEventManager.isRunning
    }
    
    public func pauseEventsSystem() {
        coreEventManager.suspend()
    }
    
    public func forceProcessEvents() {
        coreEventManager.currentlyEnabledLoops().forEach { loop in
            try? loop.performProcessing()
        }
    }
    
    public func lastProcessedEvent() -> GenericEvent? {
        eventsConveyor.lastProcessedEvent()
    }
    
    public func lastReceivedEvent() -> GenericEvent? {
        eventsConveyor.lastReceivedEvent()
    }
    
    public func eventsHistory(since anchor: EventID?) throws -> [EventsHistoryRow] {
        try eventsConveyor.history(since: anchor)
    }
}

extension Tower {
    private static let refillInterval: TimeInterval = {
        #if targetEnvironment(simulator)
        return 10.0
        #elseif os(iOS)
        return 30.0
        #elseif os(OSX)
        return 15.0
        #endif
    }()
    
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
            refillPeriod: refillInterval
        )
        
        return coreEventManager
    }
    
    /// Stop active polling and clears local storages used by the polling system.
    /// After calling this method polling needs to be re-started from scratch including fetch of initial event ID.
    func discardEventsPolling() {
        coreEventManager.suspend()
        coreEventManager.destroyAnchors()
        coreEventManager.reset()
    }
    
}
