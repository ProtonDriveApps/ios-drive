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

/// Create a Photo-Volume
struct CreatePhotoVolumeRequest: Endpoint {
    typealias Response = CreatePhotoVolumeResponse

    let request: URLRequest

    init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/volumes",
            body: parameters,
            service: service,
            credential: credential
        )
    }
}

extension CreatePhotoVolumeRequest {
    struct Parameters: Encodable {
        let share: Share
        let link: Link
    }
    
    struct Share: Encodable {
        let addressID: String
        let addressKeyID: String
        let key: String
        let passphrase: String
        let passphraseSignature: String
    }
    
    struct Link: Encodable {
        let name: String
        let nodeKey: String
        let nodePassphrase: String
        let nodePassphraseSignature: String
        let nodeHashKey: String
    }
}

struct CreatePhotoVolumeResponse: Codable {
    let code: Int
    let volume: Volume
    // TODO:album there is an additional `Type` property, check create standard volume has this property or not when backend ready
}
