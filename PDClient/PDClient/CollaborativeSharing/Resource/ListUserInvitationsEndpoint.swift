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

public struct ListUserInvitationsParameters {
    let anchorID: String?
    let pageSize: Int?
    let shareTypes: Set<ShareTargetType>

    public init(anchorID: String?, pageSize: Int? = nil, shareTypes: Set<ShareTargetType>) {
        self.anchorID = anchorID
        self.pageSize = pageSize
        self.shareTypes = shareTypes
    }
}

public struct ListUserInvitationsResponse: Codable {
    public let invitations: [InvitationResponse]
    public let anchorID: String?
    public let more: Bool
    public let code: Int

    public struct InvitationResponse: Codable {
        public let volumeID: String
        public let shareID: String
        public let invitationID: String
    }
}

/// Get  List invitations of a user
/// - GET: /drive/v2/shares/invitations
public struct ListUserInvitationsEndpoint: Endpoint {
    public typealias Response = ListUserInvitationsResponse

    public let request: URLRequest

    public init(service: APIService, credential: ClientCredential, parameters: ListUserInvitationsParameters) {
        var queries: [URLQueryItem] = []
        if let anchorID = parameters.anchorID {
            queries.append(URLQueryItem(name: "AnchorID", value: anchorID))
        }
        if let pageSize = parameters.pageSize {
            queries.append(URLQueryItem(name: "PageSize", value: String(pageSize)))
        }
        let shareTypes = parameters.shareTypes.map(\.rawValue).map(String.init)
        shareTypes.forEach { shareType in
            // Query key contains `[]` to convey array type
            queries.append(URLQueryItem(name: "ShareTargetTypes[]", value: shareType))
        }

        let url = service.url(of: "/v2/shares/invitations", queries: queries)
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        self.request = request
    }

}
