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
import PDClient

class DriveEventsLoop: EventsLoop {
    typealias Response = EventsEndpoint.Response
    typealias LogHandler = (Error) -> Void
    
    private let volumeID: String // CloudSlot and EventPeriodicScheduler work with VolumeID
    private let cloudSlot: CloudSlot
    private let conveyor: EventsConveyor
    private let observers: [EventsListener]
    private let processor: DriveEventsLoopProcessor
    private let logError: LogHandler?
    
    private let mode: DriveEventsLoopMode
    
    init(volumeID: String, cloudSlot: CloudSlot, processor: DriveEventsLoopProcessor, conveyor: EventsConveyor, observers: [EventsListener], mode: DriveEventsLoopMode, logError: LogHandler? = nil) {
        self.volumeID = volumeID
        self.cloudSlot = cloudSlot
        self.conveyor = conveyor
        self.observers = observers
        self.processor = processor
        self.mode = mode
        self.logError = logError
    }
    
    var latestLoopEventId: String? {
        get { cloudSlot.lastScannedEventID }
        set { cloudSlot.lastScannedEventID = newValue }
    }
    
    var referenceDate: Date? {
        get { cloudSlot.referenceDate }
        set { cloudSlot.referenceDate = newValue }
    }
    
    var lastEventFetchTime: Date? {
        get { cloudSlot.lastEventFetchTime }
        set { cloudSlot.lastEventFetchTime = newValue }
    }
    
    func initialEventUnknown() async {
        do {
            let eventID = try await cloudSlot.fetchInitialEvent(ofVolumeID: volumeID)
            
            latestLoopEventId = eventID
            referenceDate = Date()
            lastEventFetchTime = Date()
        } catch {
            onError(error)
        }
    }
    
    func poll(since loopEventID: String) async throws -> Response {
        if mode.contains(.pollAndRecord) {
            let response = try await cloudSlot.scanEventsFromRemote(ofVolumeID: volumeID, since: loopEventID)
            lastEventFetchTime = Date()
            return response
        } else {
            // when polling is switched off but the loop is running, we just return empty response
            // because that is a valid situation
            return Response(code: 200, events: [], eventID: loopEventID, more: .false, refresh: .false)
        }
    }

    func process(_ response: Response) async throws {
        if mode.contains(.pollAndRecord) {
            performRecording(events: response.events, till: response.lastEventID)
        }
        
        if mode.contains(.processRecords) {
            try performProcessing()
        }
    }
    
    func performRecording(events: [Event], till latest: EventID) {
        // 1. record events into conveyor
        conveyor.record(events)
        
        // 2. remember we've fetched this pack
        latestLoopEventId = latest
        
        observers.forEach {
            $0.processorReceivedEvents()
        }
    }

    func performProcessing() throws {
        conveyor.prepareForProcessing()
        
        let affectedNodes = try processor.process()
        observers.forEach {
            $0.processorAppliedEvents(affecting: affectedNodes)
        }
    }

    func nukeCache() async {
        conveyor.clearUp()
        latestLoopEventId = nil
        lastEventFetchTime = nil
        referenceDate = nil
    }

    func onError(_ error: Error) {
        guard !error.isNetworkIssueError else { return }
        logError?(error)
    }

    func onProcessingError(_ error: Error) {
        logError?(error)
    }

}

extension DriveEventsLoop.Response: EventPage {
    public var requiresClearCache: Bool {
        refresh == Refresh.true
    }
    
    public var hasMorePages: Bool {
        more == More.true
    }
    
    public var lastEventID: String {
        eventID
    }
}
