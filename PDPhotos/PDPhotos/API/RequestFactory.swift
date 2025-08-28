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
import PDCore
import PDClient
import enum ProtonCoreNetworking.HTTPMethod

struct RequestFactory {
    func make(
        method: HTTPMethod,
        path: String,
        queryItems: [String: String?] = [:],
        body: Encodable? = nil,
        service: APIService,
        credential: ClientCredential
    ) throws -> URLRequest {
        let parameters: [URLQueryItem] =  queryItems
            .filter { $0.value != nil }
            .map { .init(name: $0.key, value: $0.value) }
        let url = service.url(
            of: path,
            parameters: parameters.isEmpty ? nil : parameters
        )
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body {
            request.httpBody = try JSONEncoder(strategy: .capitalizeFirstLetter).encode(body)
        }

        return request
    }
}
