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

import CoreData

final class PhotoSmallThumbnailRepository: ThumbnailRepository {
    private let store: StorageManager

    init(store: StorageManager) {
        self.store = store
    }

    func fetchThumbnail(fileID: NodeIdentifier) throws -> Thumbnail {
        let moc = store.backgroundContext
        return try moc.performAndWait {
            let photo = try store.fetchPhoto(id: fileID, moc: moc)
            return try getThumbnail(from: photo.photoRevision)
        }
    }

    private func getThumbnail(from revision: Revision) throws -> Thumbnail {
        guard revision.uploadState != .created else {
            throw ThumbnailLoaderError.thumbnailNotYetCreated
        }
        guard let thumbnail = revision.thumbnails.first(where: { $0.type == .default }) else {
            throw ThumbnailLoaderError.nonRecoverable
        }

        return thumbnail
    }
}
