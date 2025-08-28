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

public struct AcceptInvitationParameters {
    let invitationID: String
    let bodyParameters: BodyParameters

    public init(invitationID: String, sessionKeySignature: String) {
        self.invitationID = invitationID
        self.bodyParameters = BodyParameters(sessionKeySignature: sessionKeySignature)
    }

    struct BodyParameters: Encodable {
        let sessionKeySignature: String
    }
}

public struct AcceptInvitationResponse: Codable {
    public let code: Int
}

/// Accept invitation
/// - POST: /drive/v2/shares/invitations/{invitationID}/accept
public struct AcceptInvitationEndpoint: Endpoint {
    public typealias Response = AcceptInvitationResponse

    public var request: URLRequest

    public init(parameters: AcceptInvitationParameters, service: APIService, credential: ClientCredential) throws {
        // url

        let url = service.url(of: "/v2/shares/invitations/\(parameters.invitationID)/accept")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        request.httpBody = try JSONEncoder(strategy: .capitalizeFirstLetter).encode(parameters.bodyParameters)

        self.request = request
    }
}
