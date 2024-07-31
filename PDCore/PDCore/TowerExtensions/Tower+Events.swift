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
import PMEventsManager
import ProtonCoreServices

public protocol EventsSystemManager {
    typealias EventsHistoryRow = (event: GenericEvent, share: String, objectID: NSManagedObjectID)
    
    // event scheduler
    func intializeEventsSystem()
    func runEventsSystem()
    func pauseEventsSystem()
    
    // event loops
    func forceProcessEvents()
    var eventProcessorIsRunning: Bool { get }
    
    // conveyor
    func lastEnumeratedEvent() -> GenericEvent?
    func lastUnenumeratedEvent() -> GenericEvent?
    func lastReceivedEvent() -> GenericEvent?
    func eventsHistory(since anchor: EventID?) throws -> [EventsHistoryRow]
    func setEnumerated(_ objectIDs: [NSManagedObjectID])
    
    var eventSystemReferenceDate: Date? { get }
    var eventSystemReferenceID: EventID? { get }
    var eventSystemLatestFetchTime: Date? { get }
}

extension Tower: EventsSystemManager {
    
    public func intializeEventsSystem() {
        let moc = self.storage.backgroundContext
        moc.performAndWait {
            let addressIDs = self.sessionVault.addressIDs
            let processor = DriveEventsLoopProcessor(cloudSlot: cloudSlot, conveyor: eventsConveyor, storage: storage)
            
            guard let mainShare = self.storage.mainShareOfVolume(by: addressIDs, moc: moc),
                  let volumeID = mainShare.volume?.id else {
                Log.error("Events system failed to initialize", domain: .events)
                return
            }

            let logError: DriveEventsLoop.LogHandler = {
                Log.error($0, domain: .events)
            }
            let loop = DriveEventsLoop(volumeID: volumeID, cloudSlot: self.cloudSlot, processor: processor, conveyor: self.eventsConveyor, observers: self.eventObservers, mode: self.eventProcessingMode, logError: logError)

            coreEventManager.enable(loop: loop, for: volumeID)
        }
    }
    
    public func runEventsSystem() {
        #if HAS_QA_FEATURES
        guard shouldFetchEvents != false else { return }
        #endif
        coreEventManager.start()
    }
    
    public var eventProcessorIsRunning: Bool {
        coreEventManager.isRunning
    }
    
    public func pauseEventsSystem() {
        coreEventManager.suspend()
    }
    
    public func forceProcessEvents() {
        guard !coreEventManager.currentlyEnabledLoops().isEmpty else {
            Log.error("No event loop(s) to process events", domain: .events)
            return
        }

        coreEventManager.currentlyEnabledLoops().forEach { loop in
            try? loop.performProcessing()
        }
    }

    /// Event that was recorded into events storage and both applied to metadata storage and enumerated by the system. Will be `nil` if no events have been enumerated yet or if no events present
    public func lastEnumeratedEvent() -> GenericEvent? {
        eventsConveyor.lastFullyHandledEvent()
    }
    
    /// Event that was recorded into events storage and applied to metadata storage, but not yet enumerated by the system. Will be `nil` if all events have been enumerated
    public func lastUnenumeratedEvent() -> GenericEvent? {
        eventsConveyor.lastEventAwaitingEnumeration()
    }
    
    /// Event received from API and saved into events DB.  Will be `nil` if no events were fetched from BE since latest login or cache clearing
    public func lastReceivedEvent() -> GenericEvent? {
        eventsConveyor.lastReceivedEvent()
    }
    
    public func eventsHistory(since anchor: EventID?) throws -> [EventsHistoryRow] {
        try eventsConveyor.history(since: anchor)
    }
    
    public func setEnumerated(_ objectIDs: [NSManagedObjectID]) {
        eventsConveyor.setEnumerated(objectIDs)
    }
    
    /// Moment when started tracking events (login or cache clearing caued by user or .refresh event). Will be `nil` before initial event ID of event system is recorded (during login or after cache nuking)
    public var eventSystemReferenceDate: Date? {
        eventsConveyor.referenceDate
    }
    
    public var eventSystemReferenceID: EventID? {
        eventsConveyor.referenceID
    }
    
    /// Latest date of successfull API request. Will be `nil` before initial event ID of event system is recorded (during login or after cache nuking)
    public var eventSystemLatestFetchTime: Date? {
        eventsConveyor.latestEventFetchTime
    }
}

extension Tower {
    private static let refillInterval: TimeInterval = {
        #if targetEnvironment(simulator)
        return 10.0
        #elseif os(iOS)
        return 30.0
        #else
        return 90.0
        #endif
    }()
    
    static func makeCoreEventsSystem(appGroup: SettingsStorageSuite, sessionVault: SessionVault, generalSettings: GeneralSettings, paymentsSecureStorage: PaymentsSecureStorage, network: APIService) -> CoreEventLoopManager {
        let processor = GeneralEventsLoopProcessor(sessionVault: sessionVault, generalSettings: generalSettings, paymentsVault: paymentsSecureStorage)
        
        let generalEventsLoop = GeneralEventsLoop(
            apiService: network,
            processor: processor,
            userDefaults: appGroup.userDefaults,
            logError: {
                Log.error($0, domain: .events)
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
    static func discardEventsPolling(for coreEventManager: CoreEventLoopManager) {
        coreEventManager.suspend()
        coreEventManager.destroyAnchors()
        coreEventManager.reset()
    }
    
}
