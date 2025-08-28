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

public struct PhotosListResponse: Codable, Equatable {
    public let photos: [Photo]

    public struct Photo: Codable, Equatable {
        public let linkID: String
        public let captureTime: Int
        /// nameHash
        public let hash: String
        public let contentHash: String
        // TODO:album remove optional when backend ready
        public let tags: [Int]?

        public let relatedPhotos: [Photo]? // Optional to allow using the same type for related photos (which don't have it)
        public let addedTime: Date?

        public init(
            linkID: String,
            captureTime: Int,
            addedTime: Date?,
            hash: String,
            contentHash: String,
            relatedPhotos: [Photo] = [],
            tags: [Int]? = nil
        ) {
            self.linkID = linkID
            self.captureTime = captureTime
            self.addedTime = addedTime
            self.hash = hash
            self.contentHash = contentHash
            self.relatedPhotos = relatedPhotos
            self.tags = tags
        }
    }

    public init(photos: [Photo]) {
        self.photos = photos
    }
}

public typealias RemotePhotoListing = PhotosListResponse.Photo
