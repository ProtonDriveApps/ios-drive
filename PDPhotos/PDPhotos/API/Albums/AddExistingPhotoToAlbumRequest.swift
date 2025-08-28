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
import PDClient

/// Add Photos that are already in the Volume to an Album
struct AddExistingPhotosToAlbumRequest: Endpoint {
    typealias Response = AddExistingPhotosToAlbumResponse

    let request: URLRequest

    init(volumeID: String, linkID: String, body: Body, service: APIService, credential: ClientCredential) throws {
        // Initially the client can only send maximum 10 entries per request due to potential load on the server.
        // This limit is subject to change pending improvements, but will never be lower than 10.
        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/volumes/\(volumeID)/albums/\(linkID)/add-multiple",
            body: body,
            service: service,
            credential: credential
        )
    }
}

extension AddExistingPhotosToAlbumRequest {
    struct Body: Encodable {
        let albumData: [AlbumData]
    }
    
    struct AlbumData: Encodable, Equatable {
        let linkID: String
        /// name hash
        let hash: String
        /// PGP message
        let name: String
        /// Email address used for signing name
        let nameSignatureEmail: String
        /// Passphrase should be unchanged, only key packet is updated
        let nodePassphrase: String
        /// Photo content hash
        let contentHash: String
        /// Required when moving an anonymous Link. It must be signed by the SignatureEmail address.
        let nodePassphraseSignature: String?
        /// Required when moving an anonymous link. Email address used for the NodePassphraseSignature
        let signatureEmail: String?
    }
}

public struct AddExistingPhotosToAlbumResponse: Codable {
    public let code: Int
    public let responses: [Response]
    
    public struct Response: Codable {
        public let linkID: String
        public let response: ResponseDetail
    }
    
    public struct ResponseDetail: Codable {
        public let code: Int
        public let error: String?
        public let details: Detail?
    }
    
    public struct Detail: Codable {
        /// Always sent, can be same as "LinkID"
        public let newLinkID: String
    }
}
