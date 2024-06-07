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

public class EventPeriodicScheduler<GeneralEventsLoop: EventsLoop, SpecialEventsLoop: EventsLoop> {
    public typealias LoopID = String
    
    /// Serial queue for jobs posted by all loops
    private var queue: OperationQueue
    
    /// Timer re-fills `queue` periodically when it gets empty
    private var timer: Timer?
    private let refillPeriod: TimeInterval
    
    /// Factory for event polling operation for general events
    private let generalLoopScheduler: LoopOperationScheduler<GeneralEventsLoop>
    
    /// Factories for event polling operations for per-calendar events. Key is `CalendarID`
    private var specialLoops: [LoopID: LoopOperationScheduler<SpecialEventsLoop>]
    
    public init(generalLoop: GeneralEventsLoop, refillPeriod: TimeInterval = 60) {
        self.queue = OperationQueue()
        self.queue.maxConcurrentOperationCount = 1
        self.queue.qualityOfService = .utility

        self.generalLoopScheduler = LoopOperationScheduler(loop: generalLoop, queue: queue)
        self.specialLoops = [:]
        self.refillPeriod = refillPeriod
    }
    
    public func start() {
        queue.isSuspended = false

        let timer = Timer(timeInterval: refillPeriod, repeats: true) { [weak self] _ in
            self?.refillQueueIfNeeded()
        }
        self.timer?.invalidate()
        self.timer = timer

        RunLoop.main.add(timer, forMode: .common)
        timer.fire()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func refillQueueIfNeeded() {
        guard self.queue.operationCount == 0 else { return } // schedule operations only if old ones are done

        generalLoopScheduler.addOperation()
        specialLoops.forEach { _, loop in
            loop.addOperation()
        }
    }
    
    public func suspend() {
        queue.isSuspended = true
        queue.cancelAllOperations()
        
        timer?.invalidate()
    }
    
    public func reset() {
        suspend()
        specialLoops.removeAll()
    }
    
    public func destroyAnchors() {
        generalLoopScheduler.removeAnchor()
        specialLoops.forEach { _, scheduler in
            scheduler.removeAnchor()
        }
    }
    
    public func enable(loop: SpecialEventsLoop, for calendarID: LoopID) {
        specialLoops[calendarID] = LoopOperationScheduler(loop: loop, queue: self.queue)
    }
    
    public func disable(loopFor calendarID: LoopID) {
        // stop operations in queue
        queue.operations
            .compactMap { $0 as? LoopOperation<SpecialEventsLoop> }
            .filter { $0.loop === specialLoops[calendarID] }
            .forEach { $0.cancel() }
        
        // remove from loops
        specialLoops[calendarID] = nil
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
}
