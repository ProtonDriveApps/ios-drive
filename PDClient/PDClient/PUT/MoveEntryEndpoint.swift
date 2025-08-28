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

public struct MoveEntryEndpoint: Endpoint {
    public struct Parameters: Codable {
        public let Name: String
        public let NodePassphrase: String
        public let Hash: String
        public let ParentLinkID: String
        public let NameSignatureEmail: String
        public let OriginalHash: String
        public let NewShareID: String?
        public let NodePassphraseSignature: String?
        public let SignatureEmail: String?
        /// Optional, except when moving a Photo-Link.
        public let ContentHash: String?

        public init(
            name: String,
            nodePassphrase: String,
            hash: String,
            parentLinkID: String,
            nameSignatureEmail: String,
            originalHash: String,
            newShareID: String?,
            nodePassphraseSignature: String? = nil,
            signatureEmail: String? = nil,
            contentHash: String? = nil
        ) {
            self.Name = name
            self.NodePassphrase = nodePassphrase
            self.NodePassphraseSignature = nodePassphraseSignature
            self.Hash = hash
            self.ParentLinkID = parentLinkID
            self.NameSignatureEmail = nameSignatureEmail
            self.OriginalHash = originalHash
            self.NewShareID = newShareID
            self.SignatureEmail = signatureEmail
            self.ContentHash = contentHash
        }
    }

    public struct Response: Codable {
        var code: Int
        
        public init(code: Int) {
            self.code = code
        }
    }

    public var request: URLRequest

    public init(shareID: Share.ShareID, nodeID: Link.LinkID, parameters: Parameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/shares")
        url.appendPathComponent(shareID)
        url.appendPathComponent("/links")
        url.appendPathComponent(nodeID)
        url.appendPathComponent("/move")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        request.httpBody = try? JSONEncoder().encode(parameters)

        self.request = request
    }
}
