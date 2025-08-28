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

/// Update album properties, like name and cover photo
struct UpdateAlbumRequest: Endpoint {
    typealias Response = CodeResponse

    let request: URLRequest

    init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .put,
            path: "/photos/volumes/\(parameters.volumeID)/albums/\(parameters.linkID)",
            body: parameters.body,
            service: service,
            credential: credential
        )
    }
}

extension UpdateAlbumRequest {
    struct Parameters {
        let volumeID: String
        let linkID: String
        let body: Body
    }
    
    struct Body: Codable {
        let coverLinkID: String?
        let link: Link?
    }
    
    struct Link: Codable {
        /// Encrypted album name, duplicated name is allowed
        let name: String
        let hash: String
        let nameSignatureEmail: String
        let originalHash: String
        // Name, Hash, NameSignatureEmail, OriginalHash all required together if one is sent for rename, otherwise not required; null not valid
        
        /// PGP message, sending null will set xattr to null
        let xAttr: String?
    }
}
