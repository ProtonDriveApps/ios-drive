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

import PDCore

protocol RemoteFavoritingRepositoryProtocol {
    func markStreamPhotoFavorite(id: PhotoId) async throws
    func markAlbumPhotoFavorite(id: PhotoId, body: FavoritingPhotosParameters.Body) async throws
    func removeFavoriteTag(id: PhotoId) async throws
}

final class RemoteFavoritingRepository: RemoteFavoritingRepositoryProtocol {
    private let tagClient: PhotoTagClient

    init(tagClient: PhotoTagClient) {
        self.tagClient = tagClient
    }

    func markStreamPhotoFavorite(id: PhotoId) async throws {
        let parameters = FavoritingPhotosParameters(volumeID: id.volumeID, linkID: id.id, body: nil)
        _ = try await tagClient.favoritePhoto(parameters: parameters)
    }

    func markAlbumPhotoFavorite(id: PhotoId, body: FavoritingPhotosParameters.Body) async throws {
        let parameters = FavoritingPhotosParameters(volumeID: id.volumeID, linkID: id.id, body: body)
        _ = try await tagClient.favoritePhoto(parameters: parameters)
    }

    func removeFavoriteTag(id: PhotoId) async throws {
        let parameters = AssignTagToPhotoRequest.Parameters(
            volumeID: id.volumeID,
            linkID: id.id,
            body: .init(tags: [PhotoTag.favorites])
        )
        try await tagClient.removeTagsFromPhoto(parameters: parameters)
    }
}
