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

/// List external invitations of a share
/// - GET /drive/v2/shares/{shareID}/external-invitations
struct ListExternalInvitationsEndpoint: Endpoint {
    typealias Response = ListExternalInvitationsResponse
    
    var request: URLRequest
    
    init(shareID: String, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/v2/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/external-invitations")
        
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

struct ListExternalInvitationsResponse: Codable {
    let code: Int
    let externalInvitations: [ExternalInvitation]
}
