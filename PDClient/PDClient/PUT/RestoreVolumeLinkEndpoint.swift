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

public struct RestoreVolumeLinkEndpoint: Endpoint {

    public struct Response: Codable {
        let responses: [ResponseElement]
        let code: Int

        public init(responses: [ResponseElement], code: Int) {
            self.responses = responses
            self.code = code
        }
    }

    struct Parameters {
        let volumeID: Volume.VolumeID
        let body: Body

        init(volumeID: Volume.VolumeID, linkIDs: [Link.LinkID]) {
            self.volumeID = volumeID
            body = Body(linkIDs: linkIDs)
        }

        struct Body: Encodable {
            let linkIDs: [Link.LinkID]

            private enum CodingKeys: String, CodingKey {
                case linkIDs = "LinkIDs"
            }
        }
    }

    public var request: URLRequest

    init(parameters: Parameters, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/v2/volumes")
        url.appendPathComponent(parameters.volumeID)
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
