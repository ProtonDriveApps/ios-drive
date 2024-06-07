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
import PDCore

/// Downloads thumbnails urls for given photos and stores them in local repository.
/// To map from photoId -> thumbnailId we're using `thumbnailType`.
protocol ThumbnailURLsInteractor {
    func execute(ids: PhotoIdsSet) async throws
}

final class RemoteThumbnailURLsInteractor: ThumbnailURLsInteractor {
    private let listInteractor: ThumbnailsListInteractor
    private let updateRepository: ThumbnailsUpdateRepository
    private let volumeIdDataSource: PhotosVolumeIdDataSource
    private let idsDataSource: PhotoThumbnailIdsRepository
    private let type: ThumbnailType

    init(listInteractor: ThumbnailsListInteractor, updateRepository: ThumbnailsUpdateRepository, volumeIdDataSource: PhotosVolumeIdDataSource, idsDataSource: PhotoThumbnailIdsRepository, type: ThumbnailType) {
        self.listInteractor = listInteractor
        self.updateRepository = updateRepository
        self.volumeIdDataSource = volumeIdDataSource
        self.idsDataSource = idsDataSource
        self.type = type
    }

    func execute(ids: PhotoIdsSet) async throws {
        /// Get thumbnail ids from given photos
        let ids = Array(ids)
        let thumbnailIds = idsDataSource.getIds(photoIds: ids, type: type)
        /// Request thumbnail urls from a given volume
        let volumeId = try await volumeIdDataSource.getVolumeId()
        let urls = try await listInteractor.execute(ids: thumbnailIds, volumeId: volumeId)
        /// Store urls to the repository
        try updateRepository.update(thumbnails: urls)
    }
}
