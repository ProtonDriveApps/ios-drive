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

public struct GetShareBootstrapEndpoint: Endpoint {
    public typealias Response = BootstrapedShareResponse

    public var request: URLRequest

    init(shareID: Share.ShareID, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }

    public struct BootstrapedShareResponse: Codable {
        let code: Int
        public let shareID: String
        public let volumeID: String
        public let type: Int
        public let state: Int
        public let creator: String
        public let locked: Bool?
        public let createTime: Int?
        public let modifyTime: Int?
        public let linkID: String
        public let linkType: LinkType
        public let key: String
        public let passphrase: String
        public let passphraseSignature: String
        public let addressID: String
        public let addressKeyID: String
        public let memberships: [Membership]
        public let rootLinkRecoveryPassphrase: String?

        public init(code: Int, shareID: String, volumeID: String, type: Int, state: Int, creator: String, locked: Bool?, createTime: Int?, modifyTime: Int?, linkID: String, linkType: LinkType, key: String, passphrase: String, passphraseSignature: String, addressID: String, addressKeyID: String, memberships: [Membership], rootLinkRecoveryPassphrase: String?) {
            self.code = code
            self.shareID = shareID
            self.volumeID = volumeID
            self.type = type
            self.state = state
            self.creator = creator
            self.locked = locked
            self.createTime = createTime
            self.modifyTime = modifyTime
            self.linkID = linkID
            self.linkType = linkType
            self.key = key
            self.passphrase = passphrase
            self.passphraseSignature = passphraseSignature
            self.addressID = addressID
            self.addressKeyID = addressKeyID
            self.memberships = memberships
            self.rootLinkRecoveryPassphrase = rootLinkRecoveryPassphrase
        }

        public struct Membership: Codable {
            public let memberID: String
            public let shareID: String
            public let addressID: String
            public let addressKeyID: String
            public let inviter: String
            public let permissions: Int
            public let keyPacket: String
            public let keyPacketSignature: String?
            public let sessionKeySignature: String?
            public let state: Int
            public let unlockable: Bool?
            public let createTime: Int
            public let modifyTime: Int
        }
    }
}

public typealias ShareMetadata = GetShareBootstrapEndpoint.Response
public typealias MembershipMetadata = ShareMetadata.Membership
