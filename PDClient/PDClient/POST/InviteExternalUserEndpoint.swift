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

/// To invite external user
/// POST /drive/v2/shares/{shareID}/external-invitations
public struct InviteExternalUserEndpoint: Endpoint {
    public typealias Response = InviteExternalResponse
    
    public var request: URLRequest
    
    public init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        let url = service.url(of: "/v2/shares/\(parameters.shareID)/external-invitations")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .capitalizeFirstLetter
        let body = try encoder.encode(parameters.body)
        request.httpBody = body
        self.request = request
    }
}

extension InviteExternalUserEndpoint {
    public struct Parameters {
        public let shareID: String
        public let body: Body
    }
}

extension InviteExternalUserEndpoint.Parameters {
    public struct Body: Codable {
        public let externalInvitation: Invitation
        public let emailDetails: ShareInviteEmailDetails?
        
        public init(externalInvitation: Invitation, emailDetails: ShareInviteEmailDetails?) {
            self.externalInvitation = externalInvitation
            self.emailDetails = emailDetails
        }
    }
    
    public struct Invitation: Codable {
        public let inviterAddressID: String
        public let inviteeEmail: String
        public let permissions: AccessPermission
        public let ExternalInvitationSignature: String
        
        public init(
            inviterAddressID: String,
            inviteeEmail: String,
            permissions: AccessPermission,
            ExternalInvitationSignature: String
        ) {
            self.inviterAddressID = inviterAddressID
            self.inviteeEmail = inviteeEmail
            self.permissions = permissions
            self.ExternalInvitationSignature = ExternalInvitationSignature
        }
    }
}

public struct InviteExternalResponse: Codable {
    let code: Int
    let externalInvitation: ExternalInvitation
}
