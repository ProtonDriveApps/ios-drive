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

class DriveEventsLoop: EventsLoop {
    struct Response: EventPage {
        let code = 501
        let hasMorePages = false
        let requiresClearCache = false
        let lastEventID = ""
    }
    
    var latestLoopEventId: String?
    
    func poll(since loopEventID: String) async throws -> Response {
        throw NSError.init(domain: "DriveEventsLoop", code: 777, localizedDescription: "Not implemented")
    }

    func process(_ response: Response) async throws {
        // nothing
    }

    func nukeCache() async {
        // nothing
    }

    func initialEventUnknown() async {
        // nothing
    }

    func onError(_ error: Error) {
        // log
    }

    func onProcessingError(_ error: Error) {
        // log
    }

}
