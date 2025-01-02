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

/// PUT /drive/v2/shares/{shareID}/members/{memberID}
struct UpdateShareMemberPermissionsEndpoint: Endpoint {
    struct Response: Codable {
        var code: Int
    }
    
    struct Parameters: Codable {
        let permissions: AccessPermission
        
        enum CodingKeys: String, CodingKey {
            case permissions = "Permissions"
        }
    }
    
    var request: URLRequest
    
    init(
        shareID: String,
        memberID: String,
        parameters: Parameters,
        service: APIService,
        credential: ClientCredential
    ) throws {
        // url
        var url = service.url(of: "/v2/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/members")
        url.appendPathComponent(memberID)
        
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        request.httpBody = try JSONEncoder().encode(parameters)
        
        self.request = request
    }
}
