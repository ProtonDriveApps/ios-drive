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

/// List Device objects
/// - GET: /drive/devices
public struct ListDevicesEndpoint: Endpoint {

    public var request: URLRequest

    public init(service: APIService, credential: ClientCredential) {
        let url = service.url(of: "/devices")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}

extension ListDevicesEndpoint {
    public struct Response: Codable {
        public let code: Int
        public let devices: [ShareDevice]

        public struct ShareDevice: Codable {
            public let device: Device
            public let share: Share
        }

        public struct Device: Codable {
            public let deviceID: String
            public let volumeID: String
            public let creationTime: TimeInterval
            public let modifyTime: TimeInterval?
            public let lastSyncTime: TimeInterval?
            public let type: Int
            public let syncState: Int
        }

        public struct Share: Codable {
            public let shareID: String
            public let name: String
            public let linkID: String
        }
    }
}
