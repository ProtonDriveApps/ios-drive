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

import Foundation
import PDCore

struct PhotosListSection: Equatable {
    let month: Date
    let photos: [PhotoListing]
}

struct PhotoListing: Equatable {
    let id: PhotoId
    let albumId: String?
    let captureTime: Date
    let metadata: Metadata?
    let requiresMetadata: Bool
    let secondaryPhotos: [PhotoId]

    var allIds: [PhotoId] {
        [id] + secondaryPhotos
    }

    init(
        id: PhotoId,
        albumId: String? = nil,
        captureTime: Date,
        metadata: Metadata? = nil,
        secondaryPhotos: [PhotoId] = []
    ) {
        self.id = id
        self.albumId = albumId
        self.captureTime = captureTime
        self.metadata = metadata
        requiresMetadata = metadata == nil
        self.secondaryPhotos = secondaryPhotos
    }

    struct Metadata: Equatable {
        let isShared: Bool
        let hasDirectShare: Bool
        let isVideo: Bool
        let isAvailableOffline: Bool
        let isDownloading: Bool
        let burstChildrenCount: Int?
        let isFavorite: Bool

        init(isShared: Bool = false, hasDirectShare: Bool = false, isVideo: Bool = false, isAvailableOffline: Bool = false, isDownloading: Bool = false, burstChildrenCount: Int? = nil, isFavorite: Bool = false) {
            self.isShared = isShared
            self.hasDirectShare = hasDirectShare
            self.isVideo = isVideo
            self.isAvailableOffline = isAvailableOffline
            self.isDownloading = isDownloading
            self.burstChildrenCount = burstChildrenCount
            self.isFavorite = isFavorite
        }
    }
}
