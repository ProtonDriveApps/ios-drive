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

// MARK: - Log System for PMEventsManager
public var log: ((String, String, String, Int) -> Void)?
public func trace(
    _ message: String = "",
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    log?(message, file, function, line)
}

enum EventsLoopError: Error {
    case cacheIsOutdated
    case missingLatestLoopEventID
}

final class LoopOperation<Loop: EventsLoop>: AsynchronousOperation {
    private(set) weak var loop: Loop?
    private let onDidReceiveMultiplePagesResponse: () -> Void
    private var task: Task<Void, Never>?
    
    init(loop: Loop, onDidReceiveMultiplePagesResponse: @escaping () -> Void) {
        trace()

        self.loop = loop
        self.onDidReceiveMultiplePagesResponse = onDidReceiveMultiplePagesResponse
    }
    
    override func main() {
        task = Task { [weak self] in
            defer {
                self?.task = nil
            }
            guard let self = self, let loop = self.loop else {
                // finish if loop is deallocated
                // otherwise the operation will be stuck in the queue
                // preventing scheduler from adding more operations via timer
                self?.state = .finished
                return
            }
            do {
                trace("Task do")
                let loopEventID = try self.getLatestLoopID()
                let page = try await loop.poll(since: loopEventID)

                guard !isCancelled else { return }

                guard !page.requiresClearCache else {
                    throw EventsLoopError.cacheIsOutdated
                }

                try await loop.process(page)

                guard !isCancelled else { return }

                loop.latestLoopEventId = page.lastEventID
                if page.hasMorePages {
                    trace("Task do.hasMorePages")
                    self.onDidReceiveMultiplePagesResponse()
                }
            } catch {
                trace("Task catch: \(error.localizedDescription)")
                switch error {
                case EventsLoopError.cacheIsOutdated:
                    await loop.nukeCache()
                case EventsLoopError.missingLatestLoopEventID:
                    await loop.initialEventUnknown()
                default:
                    loop.onError(error)
                }
                
            }
            self.state = .finished
        }
    }
    
    override func cancel() {
        trace()

        task?.cancel()
        task = nil
        super.cancel()
    }
    
    func getLatestLoopID() throws -> String {
        trace()

        if let loop, let eventID = loop.latestLoopEventId {
            return eventID
        } else {
            throw EventsLoopError.missingLatestLoopEventID
        }
    }

    deinit {
        trace()
    }
}
