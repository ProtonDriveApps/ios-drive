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

/// Find duplicates
/// - POST: drive/photos/volumes/{volumeID}/albums/{linkID}/duplicates
struct FindDuplicatesInAlbumRequest: Endpoint {
    typealias Response = FindDuplicatesResponse

    let request: URLRequest

    init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/volumes/\(parameters.volumeID)/albums/\(parameters.albumID)/duplicates",
            body: parameters.body,
            service: service,
            credential: credential
        )
    }
}

extension FindDuplicatesInAlbumRequest {
    struct Parameters {
        let volumeID: String
        let albumID: String
        let body: Body

        init(volumeID: String, albumID: String, nameHashes: [String]) {
            self.volumeID = volumeID
            self.albumID = albumID
            self.body = .init(nameHashes: nameHashes)
        }
    }

    struct Body: Codable {
        let nameHashes: [String]
    }
}
