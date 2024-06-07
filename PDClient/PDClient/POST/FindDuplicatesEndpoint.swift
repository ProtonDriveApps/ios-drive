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

public struct FindDuplicatesParameters: Codable {
    let volumeId: String
    let nameHashes: [String]

    public init(volumeId: String, nameHashes: [String]) {
        self.volumeId = volumeId
        self.nameHashes = nameHashes
    }
}

public struct FindDuplicatesResponse: Codable, Equatable {
    public struct Item: Codable, Equatable {
        public enum LinkState: Int, Codable {
            case draft = 0
            case active = 1
            case trashed = 2
        }

        public let hash: String
        public let contentHash: String?
        public let linkState: LinkState?
        public let clientUID: String?
        public let linkID: String?
    }

    public let duplicateHashes: [Item]
    public let code: Int
}

/// Find duplicates
/// - POST: /drive/volumes/{enc_volumeID}/photos/duplicates
struct FindDuplicatesEndpoint: Endpoint {
    typealias Response = FindDuplicatesResponse

    struct Body: Encodable {
        let NameHashes: [String]
    }

    var request: URLRequest

    init(parameters: FindDuplicatesParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/volumes")
        url.appendPathComponent(parameters.volumeId)
        url.appendPathComponent("/photos/duplicates")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body = Body(NameHashes: parameters.nameHashes)
        request.httpBody = try? JSONEncoder().encode(body)

        self.request = request
    }
}
