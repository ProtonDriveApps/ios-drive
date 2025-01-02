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

public protocol EventsSystemManager: MainVolumeEventsReferenceProtocol {
    // event scheduler
    func intializeEventsSystem(includeSharedVolumes: Bool)
    func runEventsSystem()
    func pauseEventsSystem()
    
    // event loops
    func forceProcessEvents()
    var eventProcessorIsRunning: Bool { get }
    
    #if os(iOS)
    func appendSharedVolumesEventLoops(volumeIds: [String])
    func removeSharedVolumesEventLoops(volumeIds: [String])
    func removeAllSharedVolumesEventLoops()
    #endif
}

public protocol MainVolumeEventsReferenceProtocol {
    typealias EventsHistoryRow = (event: GenericEvent, share: String, objectID: NSManagedObjectID)

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

    public func intializeEventsSystem(includeSharedVolumes: Bool) {
        do {
            let moc = storage.backgroundContext
            let volumeIds = try moc.performAndWait {
                try self.storage.getVolumeIDs(in: moc)
            }

            #if os(macOS)
            initializeSingleVolumeEventLoop(volumeId: volumeIds.myVolume)
            #endif

            #if os(iOS)
            volumeIdsController.setMainVolume(id: volumeIds.myVolume)
            volumeIdsController.addSharedVolumes(ids: volumeIds.otherVolumes)
            initializeVolumeBasedEventLoop(mainVolumeId: volumeIds.myVolume)
            if !Constants.runningInExtension && includeSharedVolumes {
                // In FileProvider we don't need other volumes events, we only show main volume
                // `includingSharedVolumes` should be true when FFs allow us to poll the shared volumes
                appendSharedVolumesEventLoops(volumeIds: volumeIds.otherVolumes)
            }
            #endif
        } catch {
            Log.error("Events system failed to initialize", domain: .events)
        }
    }

    #if os(macOS)
    private func initializeSingleVolumeEventLoop(volumeId: String) {
        let factory = EventsFactory()
        let legacyConveyor = factory.makeLegacyConveyor(tower: self)
        let loop = factory.makeEventsLoop(tower: self, conveyor: legacyConveyor, volumeId: volumeId)
        mainVolumeEventsConveyor = legacyConveyor
        coreEventManager.enable(loop: loop, for: volumeId)
    }
    #endif

    #if os(iOS)
    private func initializeVolumeBasedEventLoop(mainVolumeId: String) {
        let factory = EventsFactory()
        let referenceStorage = factory.makeVolumeReferenceStorage(tower: self, volumeId: mainVolumeId)
        let mainVolumeEventsConveyor = factory.makeVolumeConveyor(tower: self, volumeId: mainVolumeId, referenceStorage: referenceStorage)
        let loop = factory.makeEventsLoop(tower: self, conveyor: mainVolumeEventsConveyor, volumeId: mainVolumeId)
        volumeEventsReferenceStorage = referenceStorage
        self.mainVolumeEventsConveyor = mainVolumeEventsConveyor
        coreEventManager.enable(loop: loop, for: mainVolumeId)
    }

    public func appendSharedVolumesEventLoops(volumeIds: [String]) {
        guard let volumeEventsReferenceStorage else {
            Log.error("Initializing shared volume loop before events storage", domain: .events)
            return
        }

        Log.info("Adding shared volumes loops", domain: .events)
        let factory = EventsFactory()
        volumeIds.forEach { volumeId in
            let mainVolumeEventsConveyor = factory.makeVolumeConveyor(tower: self, volumeId: volumeId, referenceStorage: volumeEventsReferenceStorage)
            let loop = factory.makeEventsLoop(tower: self, conveyor: mainVolumeEventsConveyor, volumeId: volumeId)
            coreEventManager.enable(loop: loop, for: volumeId)
        }
        volumeIdsController.addSharedVolumes(ids: volumeIds)
    }

    public func removeSharedVolumesEventLoops(volumeIds: [String]) {
        Log.info("Removing shared volumes loops", domain: .events)
        volumeIdsController.removeSharedVolumes(ids: volumeIds)
        coreEventManager.removeLoops(with: volumeIds)
    }

    public func removeAllSharedVolumesEventLoops() {
        Log.info("Removing all shared volumes loops", domain: .events)
        let volumeIds = volumeIdsController.getVolumes().sharedVolumes.map(\.id)
        volumeIdsController.removeSharedVolumes(ids: volumeIds)
        coreEventManager.removeLoops(with: volumeIds)
    }
    #endif

    public func runEventsSystem() {
        guard isFetchEventsPossible() else {
            return
        }
        coreEventManager.start()
    }

    private func isFetchEventsPossible() -> Bool {
        if Constants.buildType.isQaOrBelow {
            return shouldFetchEvents != false
        } else {
            return true
        }
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

    // MARK: - MainVolumeEventsReferenceProtocol

    /// Disclaimer ⚠️
    /// `mainVolumeEventsConveyor` is created when events are initiated. The below code shouldn't be called before that.

    /// Event that was recorded into events storage and both applied to metadata storage and enumerated by the system. Will be `nil` if no events have been enumerated yet or if no events present
    public func lastEnumeratedEvent() -> GenericEvent? {
        mainVolumeEventsConveyor?.lastFullyHandledEvent()
    }
    
    /// Event that was recorded into events storage and applied to metadata storage, but not yet enumerated by the system. Will be `nil` if all events have been enumerated
    public func lastUnenumeratedEvent() -> GenericEvent? {
        mainVolumeEventsConveyor?.lastEventAwaitingEnumeration()
    }
    
    /// Event received from API and saved into events DB.  Will be `nil` if no events were fetched from BE since latest login or cache clearing
    public func lastReceivedEvent() -> GenericEvent? {
        mainVolumeEventsConveyor?.lastReceivedEvent()
    }
    
    public func eventsHistory(since anchor: EventID?) throws -> [EventsHistoryRow] {
        (try mainVolumeEventsConveyor?.history(since: anchor)) ?? []
    }
    
    public func setEnumerated(_ objectIDs: [NSManagedObjectID]) {
        mainVolumeEventsConveyor?.setEnumerated(objectIDs)
    }
    
    /// Moment when started tracking events (login or cache clearing caued by user or .refresh event). Will be `nil` before initial event ID of event system is recorded (during login or after cache nuking)
    public var eventSystemReferenceDate: Date? {
        mainVolumeEventsConveyor?.referenceDate
    }
    
    public var eventSystemReferenceID: EventID? {
        mainVolumeEventsConveyor?.referenceID
    }
    
    /// Latest date of successfull API request. Will be `nil` before initial event ID of event system is recorded (during login or after cache nuking)
    public var eventSystemLatestFetchTime: Date? {
        mainVolumeEventsConveyor?.latestEventFetchTime
    }
}

extension Tower {    
    /// Stop active polling and clears local storages used by the polling system.
    /// After calling this method polling needs to be re-started from scratch including fetch of initial event ID.
    static func discardEventsPolling(for coreEventManager: CoreEventLoopManager) {
        coreEventManager.suspend()
        coreEventManager.destroyAnchors()
        coreEventManager.reset()
    }
    
}
