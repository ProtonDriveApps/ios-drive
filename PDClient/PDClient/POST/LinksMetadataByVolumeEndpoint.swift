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

/// List Links
/// - POST: /drive/volumes/{volumeID}/links/fetch_metadata
public struct LinksMetadataByVolumeEndpoint: Endpoint {
    public let request: URLRequest
    public typealias Response = LinksResponseByVolume

    public init(service: APIService, credential: ClientCredential, parameters: LinksMetadataByVolumeParameters) {
        let url = service.url(of: "/volumes/\(parameters.volumeId)/links/fetch_metadata")

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try? JSONEncoder().encode(["LinkIDs": parameters.linkIds])
        self.request = request
    }
}

public struct LinksMetadataByVolumeParameters {
    public let volumeId: String
    public let linkIds: [String]

    public init(volumeId: String, linkIds: [String]) {
        self.volumeId = volumeId
        self.linkIds = linkIds
    }
}

public struct LinksResponseByVolume: Codable {
    public var code: Int
    public let links: [Link]

    public init(code: Int, links: [Link]) {
        self.code = code
        self.links = links
    }

    public var sortedLinks: [Link] {
        let sorter = LinkHierarchySorter()
        return sorter.sort(links: links)
    }
}
