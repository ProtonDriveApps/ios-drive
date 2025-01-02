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

struct RemoveShareMemberEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
    }

    var request: URLRequest

    init(shareID: String, memberID: String, service: APIService, credential: ClientCredential) {
        let url = service.url(of: "/v2/shares/\(shareID)/members/\(memberID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}
