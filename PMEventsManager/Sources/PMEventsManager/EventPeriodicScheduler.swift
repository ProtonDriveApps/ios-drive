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

public typealias LoopID = String

public class EventPeriodicScheduler<GeneralEventsLoop: EventsLoop, SpecialEventsLoop: EventsLoop> {
    /// Serial queue for jobs posted by all loops
    private var queue: OperationQueue
    
    /// Timer re-fills `queue` periodically when it gets empty
    private var timer: Timer?
    private let refillPeriod: TimeInterval
    
    /// Factory for event polling operation for general events
    private let generalLoopScheduler: LoopOperationScheduler<GeneralEventsLoop>
    
    /// Factories for event polling operations for per-calendar events. Key is `CalendarID`
    private var specialLoops: [LoopID: LoopOperationScheduler<SpecialEventsLoop>]

    /// Events loop polling differs. Timing controller gives us data to know which loops to trigger
    private let timingController: EventLoopsTimingController

    public init(generalLoop: GeneralEventsLoop, timingController: EventLoopsTimingController) {
        trace()

        self.queue = OperationQueue()
        self.queue.maxConcurrentOperationCount = 1
        self.queue.qualityOfService = .utility

        self.generalLoopScheduler = LoopOperationScheduler(loop: generalLoop, queue: queue)
        self.specialLoops = [:]
        self.timingController = timingController
        self.refillPeriod = timingController.getInterval()
    }
    
    public func start() {
        trace()

        queue.isSuspended = false

        let timer = Timer(timeInterval: refillPeriod, repeats: true) { [weak self] _ in
            self?.refillQueueIfNeeded()
        }
        // Invalidate the previous timer.
        self.timer?.invalidate()
        // Set the new one.
        self.timer = timer

        RunLoop.main.add(timer, forMode: .common)
        DispatchQueue.main.async { [weak self] in
            self?.refillQueueIfNeeded()
        }
    }

    deinit {
        timer?.invalidate()
        timer = nil

        trace()
    }
    
    private func refillQueueIfNeeded() {
        trace()

        let enqueuedIds = getEnqueuedLoopIds()

        // General loop is added only if not enqueued. (Isn't constrained by timing)
        if !enqueuedIds.contains(generalLoopScheduler.loop.loopId) {
            generalLoopScheduler.addOperation()
        }

        // Special loops are constrained by queue state + timing constraints
        let notEnqueuedLoops = specialLoops.filter { id, _ in
            !enqueuedIds.contains(id)
        }
        let possibleIds = notEnqueuedLoops.keys
        let readyIds = timingController.getReadyLoops(possible: Array(possibleIds))
        let readyLoops = notEnqueuedLoops.filter { id, _ in
            readyIds.contains(id)
        }
        readyLoops.forEach { _, scheduler in
            scheduler.addOperation()
        }
        timingController.setExecutedLoops(loopIds: Array(readyLoops.keys))
    }

    public func forcePolling(volumeIDs: [String]) {
        timingController.updateHistoryForForcePolling(volumeIDs: volumeIDs)
        DispatchQueue.main.async { [weak self] in
            self?.refillQueueIfNeeded()
        }
    }

    public func suspend() {
        trace()

        queue.isSuspended = true
        queue.cancelAllOperations()
        
        timer?.invalidate()
    }
    
    public func reset() {
        trace()

        suspend()
        specialLoops.removeAll()
    }
    
    public func destroyAnchors() {
        trace()

        generalLoopScheduler.removeAnchor()
        specialLoops.forEach { _, scheduler in
            scheduler.removeAnchor()
        }
    }
    
    public func enable(loop: SpecialEventsLoop, for loopID: LoopID) {
        trace()

        specialLoops[loopID] = LoopOperationScheduler(loop: loop, queue: self.queue)
    }

    public func removeLoops(with loopIds: [LoopID]) {
        trace()

        loopIds.forEach {
            specialLoops[$0] = nil
        }
    }

    public func disable(loopFor loopID: LoopID) {
        trace()
        
        // stop operations in queue
        queue.operations
            .compactMap { $0 as? LoopOperation<SpecialEventsLoop> }
            .filter { $0.loop === specialLoops[loopID] }
            .forEach { $0.cancel() }
        
        // remove from loops
        specialLoops[loopID] = nil
    }
    
    public func currentlyEnabled() -> Set<LoopID> {
        Set(specialLoops.keys)
    }
    
    public func currentlyEnabledLoops() -> [SpecialEventsLoop] {
        specialLoops.values.map(\.loop)
    }
    
    public var isRunning: Bool {
        timer?.isValid == true && !queue.isSuspended
    }

    private func getEnqueuedLoopIds() -> [LoopID] {
        return queue.operations.compactMap {
            ($0 as? LoopOperation<SpecialEventsLoop>)?.loop?.loopId ?? 
            ($0 as? LoopOperation<GeneralEventsLoop>)?.loop?.loopId
        }
    }
}
