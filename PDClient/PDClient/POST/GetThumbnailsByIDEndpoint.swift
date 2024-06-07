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

public struct GetThumbnailsByIDParameters: Codable {
    let volumeID: String
    let thumbnailIDs: [String]

    public init(volumeID: String, thumbnailIDs: [String]) {
        self.volumeID = volumeID
        self.thumbnailIDs = thumbnailIDs
    }
}

public struct ThumbnailInfo: Codable {
    public let thumbnailID: String
    public let bareURL: String
    public let token: String
}

struct GetThumbnailsByIDResponse: Codable {
    let code: Int
    let thumbnails: [ThumbnailInfo]
}

/// Get thumbnails
/// POST: /drive/volumes/{enc_volumeID}/thumbnails
struct GetThumbnailsByIDEndpoint: Endpoint {
    typealias Response = GetThumbnailsByIDResponse

    private struct Body: Encodable {
        let ThumbnailIDs: [String]
    }

    var request: URLRequest

    init(parameters: GetThumbnailsByIDParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/volumes")
        url.appendPathComponent(parameters.volumeID)
        url.appendPathComponent("/thumbnails")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body = Body(ThumbnailIDs: parameters.thumbnailIDs)
        request.httpBody = try? JSONEncoder().encode(body)

        self.request = request
    }
}
