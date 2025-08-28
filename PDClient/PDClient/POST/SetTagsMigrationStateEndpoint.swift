// Copyright (c) 2025 Proton AG
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

public struct SetTagsMigrationStateEndpoint: Endpoint {
    public struct Response: Codable {
        let code: Int
    }

    public var request: URLRequest

    public init(volumeID: String, requestBody: TagsMigrationStateRequest, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/photos/volumes")
        url.appendPathComponent(volumeID)
        url.appendPathComponent("tags-migration")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        request.httpBody = try? JSONEncoder(strategy: .capitalizeFirstLetter).encode(requestBody)

        self.request = request
    }
}

public struct TagsMigrationStateRequest: Codable {
    public let finished: Bool
    public let anchor: TagsMigrationStateAnchorRequest?

    public init(finished: Bool, anchor: TagsMigrationStateAnchorRequest?) {
        self.finished = finished
        self.anchor = anchor
    }

    public struct TagsMigrationStateAnchorRequest: Codable {
        public let lastProcessedLinkID: String
        public let lastProcessedCaptureTime: Int
        public let currentTimestamp: Int
        public let clientUID: String

        public init(lastProcessedLinkID: String, lastProcessedCaptureTime: Int, currentTimestamp: Int, clientUID: String) {
            self.lastProcessedLinkID = lastProcessedLinkID
            self.lastProcessedCaptureTime = lastProcessedCaptureTime
            self.currentTimestamp = currentTimestamp
            self.clientUID = clientUID
        }
    }
}
