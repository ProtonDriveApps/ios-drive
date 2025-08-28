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

struct ListPhotosInAlbumRequest: Endpoint {
    typealias Response = ListPhotosInAlbumResponse

    let request: URLRequest

    init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        let queryItems = [
            "AnchorID": parameters.anchorID,
            "Sort": parameters.sort.rawValue,
            "Desc": "\(parameters.desc)",
            "OnlyChildren": "\(parameters.onlyChildren)"
        ]
        self.request = try RequestFactory().make(
            method: .get,
            path: "/photos/volumes/\(parameters.volumeID)/albums/\(parameters.linkID)/children",
            queryItems: queryItems,
            service: service,
            credential: credential
        )
    }
}

extension ListPhotosInAlbumRequest {
    struct Parameters {
        let volumeID: String
        let linkID: String
        let anchorID: String?
        let sort: Sort
        /// Indicate sort order, default is 1, meaning most recent will be first
        let desc: Int
        /// If the list should include only direct children of the album.
        /// 0 or 1; default is 0, meaning all photos (stream & children) will be returned.
        let onlyChildren: Int

        init(
            volumeID: String,
            linkID: String,
            anchorID: String?,
            sort: Sort = .captured,
            desc: Bool = true,
            onlyChildren: Bool = false
        ) {
            self.volumeID = volumeID
            self.linkID = linkID
            self.anchorID = anchorID
            self.sort = sort
            self.desc = desc ? 1 : 0
            self.onlyChildren = onlyChildren ? 1 : 0
        }
    }
    
    enum Sort: String {
        /// To sort by the time the Photo was added to the Album
        case added = "Added"
        /// To sort by capture-time of the Photos in the Album
        case captured = "Captured"
    }
}

struct ListPhotosInAlbumResponse: Codable {
    let photos: [PDClient.PhotosListResponse.Photo]
    let anchorID: String?
    let more: Bool
}
