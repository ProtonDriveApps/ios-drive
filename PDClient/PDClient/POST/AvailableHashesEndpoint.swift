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

public struct AvailableHashesParameters: Codable {
    public init(hashes: [String]) {
        self.Hashes = hashes
    }
    
    var Hashes: [String]
}

public struct AvailableHashesResponse: Codable {
    public struct Photo: Codable {
        public let hash: String
    }

    public struct PhotosHashes: Codable {
        public let deletedHashes: [Photo]
    }

    public let code: Int
    public let availableHashes: [String]
    public let photos: PhotosHashes?
}

struct AvailableHashesEndpoint: Endpoint {
    typealias Response = AvailableHashesResponse
    
    var request: URLRequest
    
    init(shareID: Share.ShareID, folderID: Link.LinkID, parameters: AvailableHashesParameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/links")
        url.appendPathComponent(folderID)
        url.appendPathComponent("/checkAvailableHashes")
        
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        request.httpBody = try? JSONEncoder().encode(parameters)
        
        self.request = request
    }
}
