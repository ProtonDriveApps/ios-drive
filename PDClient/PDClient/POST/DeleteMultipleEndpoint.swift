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

public struct DeleteMultipleResponse: Codable {
    let code: Int
    let responses: LinkCodesResponseElement
}

struct DeleteMultipleParameters {
    let volumeId: Volume.VolumeID
    let body: Body

    init(volumeId: Volume.VolumeID, linkIds: [Link.LinkID]) {
        self.volumeId = volumeId
        body = Body(linkIds: linkIds)
    }

    struct Body: Encodable {
        let linkIds: [Link.LinkID]

        private enum CodingKeys: String, CodingKey {
            case linkIds = "LinkIDs"
        }
    }
}

// To delete multiple links
// POST: /v2/volumes/{volumeID}/trash/delete_multiple
struct DeleteMultipleEndpoint: Endpoint {
    typealias Response = DeleteMultipleResponse

    var request: URLRequest

    init(parameters: DeleteMultipleParameters, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/v2/volumes")
        url.appendPathComponent(parameters.volumeId)
        url.appendPathComponent("/trash")
        url.appendPathComponent("/delete_multiple")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body = try? JSONEncoder().encode(parameters.body)
        assert(body != nil, "Failed body encoding")

        request.httpBody = body

        self.request = request
    }
}
