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

/// Create a new Album
struct CreateAlbumRequest: Endpoint {
    typealias Response = CreateAlbumResponse

    let request: URLRequest

    init(volumeID: String, parameter: Parameters, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/volumes/\(volumeID)/albums",
            body: parameter,
            service: service,
            credential: credential
        )
    }
}

extension CreateAlbumRequest {
    struct Parameters: Encodable {
        /// Should biometrics be required to access this album on the client.
        /// Can't be changed after creation
        let locked: Bool
        let link: Link
    }
    
    struct Link: Encodable, Equatable {
        /// PGP message; the encrypted album name
        let name: String
        /// Name hash
        let hash: String
        let nodePassphrase: String
        /// PGP signature
        let nodePassphraseSignature: String
        let signatureEmail: String
        /// PGP private key
        let nodeKey: String
        /// PGP Private Key
        let nodeHashKey: String
        /// PGP Message, can contain e.g. the mapping to local folder/album
        let xAttr: String?
    }
}

public struct CreateAlbumResponse: Codable {
    let code: Int
    let album: Album?
    
    struct Album: Codable {
        let link: Link
    }
    
    struct Link: Codable {
        let linkID: String
    }
}

enum CreateAlbumError: Error {
    case exceedMaxAlbums
    case emptyLinkID
}
