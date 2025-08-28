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

// List Albums in the user’s own Volume
struct ListOwnedAlbumsRequest: Endpoint {
    typealias Response = ListAlbumsResponse

    let request: URLRequest

    init(volumeID: String, anchorID: String? = nil, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .get,
            path: "/photos/volumes/\(volumeID)/albums",
            queryItems: ["AnchorID": anchorID],
            service: service,
            credential: credential
        )
    }
}

struct ListAlbumsResponse: Codable {
    let code: Int
    /// It will be sorted by “LastActivityTime”
    /// meaning the Album which has a Photo added to it most recently will be first
    let albums: [RemoteAlbumListing]
    /// nil if no new page can be fetched.
    let anchorID: String?
    let more: Bool
}

struct RemoteAlbumListing: Codable, Equatable {
    let locked: Bool
    let coverLinkID: String?
    /// Last time a Photo was added to the Album
    let lastActivityTime: TimeInterval
    let photoCount: Int
    let linkID: String
    let volumeID: String
    /// If the Album is not shared, it won't have a Share(ID)
    let shareID: String?
}
