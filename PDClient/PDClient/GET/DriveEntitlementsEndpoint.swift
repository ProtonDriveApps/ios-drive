// Copyright (c) 2024 Proton AG
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

/// Expose Drive specific features available to the user, along with their specific limits.
/// - GET: /drive/entitlements
public struct DriveEntitlementsEndpoint: Endpoint {
    public let request: URLRequest

    public init(service: APIService, credential: ClientCredential) {
        // url
        let url = service.url(of: "/entitlements")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}

extension DriveEntitlementsEndpoint {
    public struct Response: Codable {
        public let code: Int
        public let entitlements: DriveEntitlements
    }
    
    public struct DriveEntitlements: Codable {
        public let publicCollaboration: Bool
        
        public init(publicCollaboration: Bool) {
            self.publicCollaboration = publicCollaboration
        }
    }
}
