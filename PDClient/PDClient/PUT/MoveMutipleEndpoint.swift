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

public struct MoveMultipleEndpoint: Endpoint {
    public struct Parameters: Codable {
        public let ParentLinkID: String
        public let Links: [Link]
        public let NameSignatureEmail: String
        public let SignatureEmail: String
        public let NewShareID: String?

        public init(
            parentLinkID: String,
            links: [Link],
            nameSignatureEmail: String,
            signatureEmail: String,
            newShareID: String?
        ) {
            self.ParentLinkID = parentLinkID
            self.Links = links
            self.NameSignatureEmail = nameSignatureEmail
            self.SignatureEmail = signatureEmail
            self.NewShareID = newShareID
        }
    }

    public struct Link: Codable {
        public let LinkID: String
        public let Name: String
        public let NodePassphrase: String
        public let Hash: String
        /// Current name hash before move operation.
        public let OriginalHash: String
        /// except when moving a Photo-Link. Photo content hash
        public let ContentHash: String?
        /// Required when moving an anonymous Link. It must be signed by the SignatureEmail address.
        public let NodePassphraseSignature: String?

        public init(
            linkID: String,
            name: String,
            nodePassphrase: String,
            hash: String,
            originalHash: String,
            contentHash: String?,
            nodePassphraseSignature: String?
        ) {
            self.LinkID = linkID
            self.Name = name
            self.NodePassphrase = nodePassphrase
            self.Hash = hash
            self.OriginalHash = originalHash
            self.ContentHash = contentHash
            self.NodePassphraseSignature = nodePassphraseSignature
        }
    }

    public struct Response: Codable {
        var code: Int

        public init(code: Int) {
            self.code = code
        }
    }

    public var request: URLRequest

    public init(volumeID: Volume.VolumeID, parameters: Parameters, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/volumes")
        url.appendPathComponent(volumeID)
        url.appendPathComponent("/links")
        url.appendPathComponent("/move-multiple")

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
