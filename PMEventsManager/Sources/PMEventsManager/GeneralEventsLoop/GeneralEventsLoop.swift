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
import Combine
import ProtonCoreNetworking
import ProtonCoreServices

public class GeneralEventsLoop<Processor: EventLoopProcessor>: EventsLoop where Processor.Response == GeneralLoopResponse {
    public typealias Response = GeneralLoopResponse
    public typealias LogHandler = (Error) -> Void
    private typealias Router = EventAPIRoutes.Router

    @UserDefaultsStore("\(GeneralEventsLoop.self)") var generalLoopEventID: String?

    private let apiService: APIService
    private let processor: Processor
    private let logError: LogHandler?

    public init(apiService: APIService,
                processor: Processor,
                userDefaults: UserDefaults,
                logError: LogHandler? = nil)
    {
        self.apiService = apiService
        self.processor = processor
        self.logError = logError
        self.$generalLoopEventID.store = userDefaults
    }

    // MARK: - Initnial event

    public var latestLoopEventId: String? {
        get { generalLoopEventID }
        set { generalLoopEventID = newValue }
    }

    // Unique loop identifier
    public var loopId: String {
        return "GeneralEventsLoop"
    }

    /// Fetches the latest event ID from the server and stores it in the user defaults, do this if the initial event ID is not cached
    public func initialEventUnknown() async {
        do {
            let request: Router = .getLatestEventID
            let response: EventLatestIDResponse = try await apiService.exec(route: request)
            latestLoopEventId = response.eventID
        } catch {
            onError(error)
        }
    }

    // MARK: - Event paging

    public func poll(since loopEventID: String) async throws -> Response {
        let request: Router = .getEvent(eventID: loopEventID)
        let response: GeneralLoopResponse = try await apiService.exec(route: request)
        return response
    }

    // MARK: - Relay to Processor

    public func process(_ response: Response) async throws {
        processor.process(response: response, loopID: String(describing: Self.self))
    }

    public func nukeCache() async {
        await processor.nukeCache()
    }

    // MARK: - Error handling

    public func onError(_ error: Error) {
        guard !error.isNetworkIssueError else { return }
        logError?(error)
    }

    public func onProcessingError(_ error: Error) {
        logError?(error)
    }

}
