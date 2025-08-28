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

public struct ReturnInvitationInformationParameters {
    let invitationID: String

    public init(invitationID: String) {
        self.invitationID = invitationID
    }
}

public struct ReturnInvitationInformationResponse: Codable {
    public let invitation: InvitationResponse
    public let share: ShareResponse
    public let link: LinkResponse
    public let code: Int

    public struct InvitationResponse: Codable {
        public let invitationID: String
        public let inviterEmail: String
        public let inviteeEmail: String
        public let permissions: Int
        public let keyPacket: String
        public let keyPacketSignature: String
        public let createTime: Int

        init(invitationID: String, inviterEmail: String, inviteeEmail: String, permissions: Int, keyPacket: String, keyPacketSignature: String, createTime: Int) {
            self.invitationID = invitationID
            self.inviterEmail = inviterEmail
            self.inviteeEmail = inviteeEmail
            self.permissions = permissions
            self.keyPacket = keyPacket
            self.keyPacketSignature = keyPacketSignature
            self.createTime = createTime
        }
    }

    public struct ShareResponse: Codable {
        public let shareID: String
        public let volumeID: String
        public let passphrase: String
        public let shareKey: String
        public let creatorEmail: String

        init(shareID: String, volumeID: String, passphrase: String, shareKey: String, creatorEmail: String) {
            self.shareID = shareID
            self.volumeID = volumeID
            self.passphrase = passphrase
            self.shareKey = shareKey
            self.creatorEmail = creatorEmail
        }
    }

    public struct LinkResponse: Codable {
        public let type: Int
        public let linkID: String
        public let name: String
        public let MIMEType: String?

        init(type: Int, linkID: String, name: String, MIMEType: String?) {
            self.type = type
            self.linkID = linkID
            self.name = name
            self.MIMEType = MIMEType
        }
    }
}

/// Return Invitation Information
/// - GET: /drive/v2/shares/invitations/{InvitationID}
public struct ReturnInvitationInformationEndpoint: Endpoint {
    public typealias Response = ReturnInvitationInformationResponse

    public let request: URLRequest

    public init(service: APIService, credential: ClientCredential, parameters: ReturnInvitationInformationParameters) {
        let url = service.url(of: "/v2/shares/invitations/\(parameters.invitationID)")
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        self.request = request
    }
}
