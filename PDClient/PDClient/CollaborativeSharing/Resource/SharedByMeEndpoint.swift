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

public struct SharedByMeListParameters {
    let volumeId: String
    let anchorID: String?

    public init(volumeId: String, anchorID: String?) {
        self.volumeId = volumeId
        self.anchorID = anchorID
    }
}

public struct SharedByMeListResponse: Codable {
    public let links: [Link]
    public let anchorID: String?
    public let more: Bool
    public let code: Int

    public struct Link: Codable {
        public let contextShareID: String
        public let shareID: String
        public let linkID: String
    }
}

/// Get Revision
/// - GET: /drive/v2/volumes/{volumeID}/shares
public struct SharedByMeEndpoint: Endpoint {
    public typealias Response = SharedByMeListResponse

    public let request: URLRequest

    public init(service: APIService, credential: ClientCredential, parameters: SharedByMeListParameters) {
        var queries: [URLQueryItem] = []
        if let anchorID = parameters.anchorID {
            queries.append(URLQueryItem(name: "AnchorID", value: anchorID))
        }
        let url = service.url(of: "/v2/volumes/\(parameters.volumeId)/shares", queries: queries)
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        self.request = request
    }

}
