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
import os.log
import PDClient

public class EventsProcessor {
    static let refillInterval: TimeInterval = {
        #if targetEnvironment(simulator)
        return 10.0
        #elseif os(iOS)
        return 30.0
        #elseif os(OSX)
        return 15.0
        #endif
    }()

    private let logger: OSLog = OSLog(subsystem: "PDCore", category: "EventsProcessor")
    private var shareID: String?
    private var observers: [EventsListener]
    private var observedLanes: [EventsProvider]
    private var storage: StorageManager
    private var processLocally: Bool

    private var moc: NSManagedObjectContext {
        // should be a dedicated background context to exclude deadlock by CloudSlot operations
        self.storage.eventsContext
    }

    private var timer: Timer?
    private let conveyor: EventsConveyor
    private var isSuspended = false

    public var isRunning: Bool {
        timer?.isValid ?? false
    }

    init(storage: StorageManager, eventsConveyor: EventsConveyor, observers: [EventsListener], observedLanes: [EventsProvider], processLocally: Bool) {
        self.storage = storage
        self.observers = observers
        self.observedLanes = observedLanes
        self.conveyor = eventsConveyor
        self.processLocally = processLocally

        os_log("Lanes: %@", log: self.logger, type: .default, observedLanes.map(String.init(describing:)).joined(separator: ", "))
    }

    deinit {
        self.stopTimer()
    }

    public func start(for shareID: String) {
        self.shareID = shareID

        DispatchQueue.main.async { // important to have it on long-living thread
            let interval = EventsProcessor.refillInterval
            os_log("Start timer %d", log: self.logger, type: .default, interval)
            self.timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(self.pullEvents), userInfo: nil, repeats: true)
        }
    }

    public func stopTimer() {
        os_log("Stop timer", log: self.logger, type: .default)
        self.timer?.invalidate()
        self.timer = nil
    }

    public func suspend(_ isSuspended: Bool) {
        self.isSuspended = isSuspended
    }

    func discard() {
        self.stopTimer()
        os_log("Discard all lanes", log: self.logger, type: .default)
        self.conveyor.clearUp()
        self.observedLanes.forEach { $0.clearUp() }
    }

    @objc func pullEvents() {
        guard !isSuspended else { return }

        #if DEBUG
        let _check = Activity("Check all lanes for events", options: .detached)
        var _scope = _check.enter()
        defer { _scope.leave() }
        #endif

        guard let shareID = self.shareID else {
            return
        }
        var needsClearCache = false
        var needsPagination = false

        self.moc.perform {

            os_log("Check all lanes for events", log: self.logger, type: .default)
            let semaphore = DispatchSemaphore(value: 0)
            for lane in self.observedLanes {
                #if DEBUG
                var _scope = Activity("Lane - get", parent: _check).enter()
                defer { _scope.leave() }
                #endif

                lane.scanEventsFromRemote(of: shareID) { result in
                    switch result {
                    case .success(let newPack):
                        os_log("%@ received events: %d", log: self.logger, type: .default, String(describing: type(of: lane)), newPack.events.count)
                        lane.recordEventsIntoConveyor(pack: newPack, for: shareID, to: self.conveyor.persistentQueue)
                        needsPagination = newPack.more

                    case .failure(let error) where error is RefreshError:
                        needsClearCache = true
                        NotificationCenter.default.post(name: .nukeCache, object: nil)

                    default:
                        break
                    }

                    semaphore.signal()
                }
                semaphore.wait()
            }
            os_log("Done checking all lanes for events", log: self.logger, type: .default)

            guard !needsClearCache else {
                os_log("Received .refresh flag: skip processing, disable timer", log: self.logger, type: .default)
                self.discard()
                return
            }

            if self.processLocally {
                #if DEBUG
                var _scope = Activity("Process", parent: _check).enter()
                defer { _scope.leave() }
                #endif

                os_log("Pulled all events into conveyor, start processing...", log: self.logger, type: .default)
                self.process()
                os_log("Done processing", log: self.logger, type: .default)
            } else {
                self.prepareEvents()
            }

            guard !needsPagination else {
                os_log("Received .more flag: Run events loop again", log: self.logger, type: .default)
                self.timer?.fire()
                return
            }
        }
    }

    /// decide which events should or should not be ignored, pass for processing to a relevant Lane
    public func process() {
        self.prepareEvents()

        var affectedNodes: [NodeIdentifier] = []
        while let (event, shareID, providerType, objectID) = self.conveyor.next() {
            #if DEBUG
            var _scope = Activity("Process event", parent: .current).enter()
            defer { _scope.leave() }
            #endif
            guard let lane = self.lane(with: providerType) else {
                os_log("Event requires unknown lane type: %@ ", log: self.logger, type: .error, "\(providerType)")
                return // no lane known how to work with this event meta
            }

            let universalNodeID = lane.convert(event.inLaneNodeId, storage: self.storage, moc: self.moc)
            let universalNodeParentID = lane.convert(event.inLaneParentId, storage: self.storage, moc: self.moc)
            os_log("%@ processes event %@ id: %@ parent id: %@", log: self.logger, type: .default, "\(providerType)", "\(event.genericType)", universalNodeID ?? "-", universalNodeParentID ?? "-")

            switch event.genericType {
            case .create where self.nodeExists(id: universalNodeParentID): // need to know parent
                let updated = lane.update(shareId: shareID, from: event, storage: self.storage, moc: self.moc)
                affectedNodes.append(contentsOf: updated)

            case .updateMetadata where self.nodeExists(id: universalNodeParentID) || self.nodeExists(id: universalNodeID): // need to know node (move from) or the new parent (move to)
                let updated = lane.update(shareId: shareID, from: event, storage: self.storage, moc: self.moc)
                affectedNodes.append(contentsOf: updated)

            case [.delete, .updateContent] where self.nodeExists(id: universalNodeID):  // need to know node
                let updated = lane.update(shareId: shareID, from: event, storage: self.storage, moc: self.moc)
                affectedNodes.append(contentsOf: updated)

            default: // ignore event
                os_log("%@ ignores event %@ because it is not relevant for current metadata", log: self.logger, type: .default, "\(providerType)", "\(event.genericType)")
                lane.ignored(event: event, storage: self.storage, moc: self.moc)
            }

            os_log("%@ done processing event %@, removing it", log: self.logger, type: .default, "\(providerType)", "\(event.genericType)")
            self.conveyor.completeProcessing(of: objectID)
        }

        do {
            if self.moc.hasChanges {
                try self.moc.save()
                os_log("Saved moc", log: self.logger, type: .default)
            }
        } catch let error {
            assert(false, error.localizedDescription)
            os_log("Failed to save moc", log: self.logger, type: .error)
        }
        
        os_log("Notify observers of completion", log: self.logger, type: .default)
        self.observers.forEach {
            $0.processorAppliedEvents(affecting: affectedNodes)
        }
    }

    private func prepareEvents() {
        self.conveyor.prepareForProcessing()

        guard self.conveyor.eventsAreReady() else {
            return
        }

        os_log("Notify observers of receipt", log: self.logger, type: .default)
        self.observers.forEach {
            $0.processorReceivedEvents()
        }
    }
    
    private func nodeExists(id: String?) -> Bool {
        guard let id = id else { return false }
        return self.storage.exists(with: id, in: self.moc)
    }

    private func lane(with desiredType: EventsProvider.Type) -> EventsProvider? {
        return self.observedLanes.first(where: { desiredType == type(of: $0) })
    }
}
