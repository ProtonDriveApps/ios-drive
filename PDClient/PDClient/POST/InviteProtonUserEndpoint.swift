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

/// To invite a proton user
/// - POST /drive/v2/shares/{shareID}/invitations
public struct InviteProtonUserEndpoint: Endpoint {
    public typealias Response = InviteProtonUserResponse
    
    public var request: URLRequest
    
    public init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        let url = service.url(of: "/v2/shares/\(parameters.shareID)/invitations")
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

extension InviteProtonUserEndpoint {
    public struct Parameters {
        public let shareID: String
        public let body: Body
    }
}

extension InviteProtonUserEndpoint.Parameters {
    public struct Body: Codable {
        public let emailDetails: ShareInviteEmailDetails?
        public let invitation: Invitation
        
        public init(emailDetails: ShareInviteEmailDetails?, invitation: Invitation) {
            self.emailDetails = emailDetails
            self.invitation = invitation
        }
    }
    
    public struct Invitation: Codable {
        public let inviteeEmail: String
        public let inviterEmail: String
        public let keyPacket: String
        public let keyPacketSignature: String
        public let permissions: AccessPermission
        
        public init(
            inviteeEmail: String,
            inviterEmail: String,
            keyPacket: String,
            keyPacketSignature: String,
            permissions: AccessPermission
        ) {
            self.inviteeEmail = inviteeEmail
            self.inviterEmail = inviterEmail
            self.keyPacket = keyPacket
            self.keyPacketSignature = keyPacketSignature
            self.permissions = permissions
        }
    }
}

public struct ShareInviteEmailDetails: Codable {
    public let itemName: String
    public let message: String
    
    public init(itemName: String, message: String) {
        self.itemName = itemName
        self.message = message
    }
}

public struct InviteProtonUserResponse: Codable {
    let code: Int
    let invitation: ShareMemberInvitation
}
