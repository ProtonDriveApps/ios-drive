// Copyright (c) 2023 Proton AG
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
import PDClient

struct PhotosListLoadId: Equatable {
    let photoId: PhotoListId?
}

final class PhotosListLoadInteractor: Interactor {
    private let volumeIdDataSource: PhotosVolumeIdDataSource
    private let listing: PhotosListing

    init(volumeIdDataSource: PhotosVolumeIdDataSource, listing: PhotosListing) {
        self.volumeIdDataSource = volumeIdDataSource
        self.listing = listing
    }

    func execute(with input: PhotosListLoadId) async throws -> PhotosListResponse {
        let volumeId = try await volumeIdDataSource.getVolumeId()
        let parameters = PhotosListRequestParameters(volumeId: volumeId, lastId: input.photoId, pageSize: 500)
        return try await listing.getPhotosList(with: parameters)
    }
}
