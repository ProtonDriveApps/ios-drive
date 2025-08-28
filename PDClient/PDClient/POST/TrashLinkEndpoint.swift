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

public struct TrashLinksParameters {
    let shareId: Share.ShareID
    let parentLinkId: Link.LinkID
    let linkIds: [Link.LinkID]

    public init(shareId: Share.ShareID, parentLinkId: Link.LinkID, linkIds: [Link.LinkID]) {
        self.shareId = shareId
        self.parentLinkId = parentLinkId
        self.linkIds = linkIds
    }
}

/// Trash Children
/// /shares/{enc_shareID}/folders/{enc_linkID}/trash_multiple
public struct TrashLinkEndpoint: Endpoint {
    public typealias Response = MultipleLinkResponse

    struct Body: Encodable {
        let linkIDs: [Link.LinkID]

        private enum CodingKeys: String, CodingKey {
            case linkIDs = "LinkIDs"
        }
    }

    public var request: URLRequest

    init(parameters: TrashLinksParameters, service: APIService, credential: ClientCredential, breadcrumbs: Breadcrumbs) throws {
        var url = service.url(of: "/shares")
        url.appendPathComponent(parameters.shareId)
        url.appendPathComponent("/folders")
        url.appendPathComponent(parameters.parentLinkId)
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
            let message = "Tried to trash a folder with invalid linkID(s) \(invalidLinkIDs) [folderID \(parameters.parentLinkId), shareID \(parameters.shareId)], breadcrumbs: \(breadcrumbs.collect().reduceIntoErrorMessage())"
            assertionFailure(message)
            throw InvalidLinkIdError(detailedMessage: message)
        }
        
        let body = try? JSONEncoder().encode(Body(linkIDs: validLinkIDs))
        assert(body != nil, "Failed body encoding")

        request.httpBody = body

        self.request = request
    }
}

public struct MultipleLinkResponse: Codable {
    public let code: Int
    public let responses: [LinkResponse]
    
    public init(code: Int, responses: [LinkResponse]) {
        self.code = code
        self.responses = responses
    }

    public struct LinkResponse: Codable {
        public let linkID: String
        public let response: ErrorResponse

        public init(linkID: String, response: ErrorResponse) {
            self.linkID = linkID
            self.response = response
        }
    }

    public struct ErrorResponse: Codable {
        public let code: Int
        public let error: String?

        public init(code: Int, error: String?) {
            self.code = code
            self.error = error
        }
    }
}
