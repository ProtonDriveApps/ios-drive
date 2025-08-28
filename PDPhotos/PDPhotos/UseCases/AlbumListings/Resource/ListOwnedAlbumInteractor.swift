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

protocol ListRemoteAlbumInteractorProtocol {
    func execute() async throws -> [RemoteAlbumListing]
}

/// List all of owned albums
final class ListOwnedAlbumInteractor: ListRemoteAlbumInteractorProtocol {
    private let client: PhotoListAlbumsAPIService
    private let photoVolumeID: String

    init(client: PhotoListAlbumsAPIService, photoVolumeID: String) {
        self.client = client
        self.photoVolumeID = photoVolumeID
    }

    func execute() async throws -> [RemoteAlbumListing] {
        var anchorID: String?
        var hasMore = false
        var albums: [RemoteAlbumListing] = []
        repeat {
            let response = try await fetchAlbumList(anchorID: anchorID)
            albums.append(contentsOf: response.albums)
            anchorID = response.anchorID
            hasMore = response.more
        } while anchorID != nil && hasMore
        return albums
    }

    private func fetchAlbumList(anchorID: String?) async throws -> ListAlbumsResponse {
        let response = try await client.listOwnedAlbums(volumeID: photoVolumeID, anchorID: anchorID)
        return response
    }
}
