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

struct RestoreLinkEndpoint: Endpoint {

    public struct Response: Codable {
        let responses: [ResponseElement]
        let code: Int
    }

    struct Parameters {
        let shareID: Share.ShareID
        let body: Body

        init(shareID: Share.ShareID, linkIDs: [Link.LinkID]) {
            self.shareID = shareID
            body = Body(linkIDs: linkIDs)
        }

        struct Body: Encodable {
            let linkIDs: [Link.LinkID]

            private enum CodingKeys: String, CodingKey {
                case linkIDs = "LinkIDs"
            }
        }
    }

    var request: URLRequest

    init(parameters: Parameters, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/shares")
        url.appendPathComponent(parameters.shareID)
        url.appendPathComponent("/trash")
        url.appendPathComponent("/restore_multiple")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body = try? JSONEncoder().encode(parameters.body)
        assert(body != nil, "Failed body encoding")

        request.httpBody = body

        self.request = request
    }
}

struct ResponseElement: Codable {
    let linkID: String?
    let response: ResponseResponse?
}

struct ResponseResponse: Codable {
    let error, errorDescription: String?
    let code: Int
}
