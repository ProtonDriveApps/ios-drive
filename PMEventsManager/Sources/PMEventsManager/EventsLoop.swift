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

/// Concrete events loop needs to know its endpoint (make request and parse response) and apply received information to local storage (either clear cache or update it)
public protocol EventsLoop: AnyObject {
    associatedtype Response: EventPage
    
    // async because of network call
    func poll(since loopEventID: String) async throws -> Response
    
    // async because of db
    func process(_ response: Response) async throws
    func nukeCache() async
    func initialEventUnknown() async
    
    // sync
    func onError(_ error: Error)
    func onProcessingError(_ error: Error)
    
    var latestLoopEventId: String? { get set }
}
