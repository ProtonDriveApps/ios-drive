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
import PDClient

protocol CloudEventProvider {
    func fetchInitialEvent(ofVolumeID volumeID: String) async throws -> EventID
    func scanEventsFromRemote(ofVolumeID volumeID: String, since loopEventID: EventID) async throws -> EventsEndpoint.Response
}

extension CloudSlot: CloudEventProvider {
    
    func fetchInitialEvent(ofVolumeID volumeID: String) async throws -> EventID {
        try await withCheckedThrowingContinuation { continuation in
            client.getLatestEvent(volumeID, completion: continuation.resume)
        }
    }
    
    func scanEventsFromRemote(ofVolumeID volumeID: String, since loopEventID: EventID) async throws -> EventsEndpoint.Response {
        try await withCheckedThrowingContinuation { continuation in
            client.getEvents(volumeID, since: loopEventID, completion: continuation.resume)
        }
    }
    
}
