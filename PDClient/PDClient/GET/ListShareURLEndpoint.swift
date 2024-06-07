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

/// List ShareURLs by volume
/// - GET: /drive/volumes/{enc_volumeID}/urls
public struct ListShareURLEndpoint: Endpoint {
    public var request: URLRequest

    public init(parameters: Parameters, service: APIService, credential: ClientCredential) {
        var queries: [URLQueryItem] = []
        if let page = parameters.page {
            queries.append(URLQueryItem(name: "Page", value: "\(page)"))
        }
        if let pageSize = parameters.pageSize {
            queries.append(URLQueryItem(name: "PageSize", value: "\(pageSize)"))
        }

        let url = service.url(of: "/volumes/\(parameters.volumeId)/urls", queries: queries)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}

extension ListShareURLEndpoint {
    public struct Parameters {
        public let volumeId: String
        public let page: Int?
        public let pageSize: Int?
    }

    public struct Response: Codable {
        public let shareURLContexts: [ShareURLContext]
        public let code: Int
        public let more: Bool

        public struct ShareURLContext: Codable {
            public let contextShareID: String
            public let shareURLs: [ShareURLMeta]
            public let linkIDs: [String]
        }
    }
}
