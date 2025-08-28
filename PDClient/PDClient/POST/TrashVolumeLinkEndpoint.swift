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

public struct TrashVolumeLinksParameters {
    public let volumeID: String
    public let linkIds: [String]

    public init(volumeID: String, linkIds: [String]) {
        self.volumeID = volumeID
        self.linkIds = linkIds
    }
}

/// Trash links
/// /v2/volumes/{volumeID}/trash_multiple
public struct TrashVolumeLinkEndpoint: Endpoint {
    public typealias Response = MultipleLinkResponse

    struct Body: Encodable {
        let linkIDs: [Link.LinkID]

        private enum CodingKeys: String, CodingKey {
            case linkIDs = "LinkIDs"
        }
    }

    public var request: URLRequest

    init(parameters: TrashVolumeLinksParameters, service: APIService, credential: ClientCredential, breadcrumbs: Breadcrumbs) throws {
        var url = service.url(of: "/v2/volumes")
        url.appendPathComponent(parameters.volumeID)
        url.appendPathComponent("/trash_multiple")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let validLinkIDs = parameters.linkIds.filter { UUID(uuidString: $0) == nil }
        guard !validLinkIDs.isEmpty else {
            // if there are no valid linkIDs at all, there's no need to make the trash request at all
            let invalidLinkIDs = parameters.linkIds.compactMap { UUID(uuidString: $0) }
            let message = "Tried to trash a folder with invalid linkID(s) \(invalidLinkIDs), breadcrumbs: \(breadcrumbs.collect().reduceIntoErrorMessage())"
            assertionFailure(message)
            throw InvalidLinkIdError(detailedMessage: message)
        }

        let body = try? JSONEncoder().encode(Body(linkIDs: validLinkIDs))
        assert(body != nil, "Failed body encoding")

        request.httpBody = body

        self.request = request
    }
}
