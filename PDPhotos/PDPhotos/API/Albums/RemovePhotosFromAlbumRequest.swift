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

struct RemovePhotosFromAlbumRequest: Endpoint {
    typealias Response = RemovePhotosFromAlbumResponse

    let request: URLRequest

    init(
        volumeID: String,
        linkID: String,
        photoLinkIDs: [String],
        service: APIService,
        credential: ClientCredential
    ) throws {
        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/volumes/\(volumeID)/albums/\(linkID)/remove-multiple",
            body: ["LinkIDs": photoLinkIDs],
            service: service,
            credential: credential
        )
    }
}

struct RemovePhotosFromAlbumResponse: Codable {
    let code: Int
    let responses: [Response]
    
    struct Response: Codable {
        let linkID: String
        let response: LinkResponseDetail
    }
    
    struct LinkResponseDetail: Codable {
        let code: Int
    }
}
