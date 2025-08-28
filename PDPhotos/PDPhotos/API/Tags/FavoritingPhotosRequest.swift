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
import PDClient

/// Because the user expects to find all their favorites easily
/// including those directly uploaded to albums, all favorites should be in the root.
/// This behavior was specifically requested by product.
///
/// Only the main-Photo can be favorited.
struct FavoritingPhotosRequest: Endpoint {
    typealias Response = FavoritingPhotosResponse

    let request: URLRequest

    init(parameters: FavoritingPhotosParameters, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/volumes/\(parameters.volumeID)/links/\(parameters.linkID)/favorite",
            body: parameters.body,
            service: service,
            credential: credential
        )
    }
}

public struct FavoritingPhotosParameters {
    let volumeID: String
    let linkID: String
    /// The entire body of the request optional
    /// and only needed when the user wants to favorite a Photo directly uploaded to an Album (the parent-Node is not the Root-Node)
    /// or in a foreign Volume.
    let body: Body?

    struct Body: Codable {
        let photoData: PhotoData
    }

    // The data in the request-body must be encrypted using the Node-Key of the Photo-Share Root-Node.
    struct PhotoData: Codable {
        /// Name hash
        let hash: String
        /// PGP message
        let name: String
        /// Email address used for signing name
        let nameSignatureEmail: String
        /// Passphrase should be unchanged, only key packet is updated
        let nodePassphrase: String
        /// Photo content hash
        let contentHash: String
        /// Required when moving an anonymous Node.
        /// It must be signed by the SignatureEmail address.
        let nodePassphraseSignature: String?
        /// Nullable: Required when moving an anonymous Node. Email address used for the NodePassphraseSignature
        let signatureEmail: String?
        let relatedPhotos: [RelatedPhoto]
    }

    struct RelatedPhoto: Codable {
        let linkID: String
        /// Name hash
        let hash: String
        /// PGP message
        let name: String
        /// Email address used for signing name
        let nameSignatureEmail: String
        /// Passphrase should be unchanged, only key packet is updated
        let nodePassphrase: String
        /// Photo content hash
        let contentHash: String
        /// Required when moving an anonymous Node.
        /// It must be signed by the SignatureEmail address.
        let nodePassphraseSignature: String?
        /// Nullable: Required when moving an anonymous Node. Email address used for the NodePassphraseSignature
        let signatureEmail: String?
    }
}

public typealias FavoritingPhotosResponse = CodeResponse
