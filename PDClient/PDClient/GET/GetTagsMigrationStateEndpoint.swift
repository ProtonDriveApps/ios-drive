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

public struct GetTagsMigrationStateEndpoint: Endpoint {
    public typealias Response = TagsMigrationStateResponse

    public var request: URLRequest

    public init(volumeID: String, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/photos/volumes")
        url.appendPathComponent(volumeID)
        url.appendPathComponent("tags-migration")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }

    public struct TagsMigrationStateResponse: Codable {
        public let code: Int
        public let finished: Bool
        public let anchor: TagsMigrationAnchorResponse?

        public struct TagsMigrationAnchorResponse: Codable {
            public let lastProcessedLinkID: String
            public let lastProcessedCaptureTime: Int
            public let lastMigrationTimestamp: Int
            public let lastClientUID: String?

            public init(lastProcessedLinkID: String, lastProcessedCaptureTime: Int, lastMigrationTimestamp: Int, lastClientUID: String?) {
                self.lastProcessedLinkID = lastProcessedLinkID
                self.lastProcessedCaptureTime = lastProcessedCaptureTime
                self.lastMigrationTimestamp = lastMigrationTimestamp
                self.lastClientUID = lastClientUID
            }
        }
    }
}
