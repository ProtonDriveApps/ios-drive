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

/// To delete an album, bypassing trash and the Album will be irrecoverable by the user.
struct DeleteAlbumRequest: Endpoint {
    typealias Response = CodeResponse

    let request: URLRequest

    init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .delete,
            path: "/photos/volumes/\(parameters.volumeID)/albums/\(parameters.linkID)",
            queryItems: ["DeleteAlbumPhotos": parameters.deleteAlbumPhotos ? "1" : "0"],
            service: service,
            credential: credential
        )
    }
}

extension DeleteAlbumRequest {
    struct Parameters {
        let volumeID: String
        let linkID: String
        // To force delete album even if it has direct children
        let deleteAlbumPhotos: Bool

        init(volumeID: String, linkID: String, deleteAlbumPhotos: Bool = false) {
            self.volumeID = volumeID
            self.linkID = linkID
            self.deleteAlbumPhotos = deleteAlbumPhotos
        }
    }
}
