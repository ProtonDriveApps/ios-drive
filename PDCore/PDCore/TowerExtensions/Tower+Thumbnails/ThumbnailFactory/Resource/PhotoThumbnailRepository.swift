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

final class PhotoNodeThumbnailRepository: NodeThumbnailRepository {
    private let store: StorageManager
    private let typeStrategy: ThumbnailTypeStrategy

    init(store: StorageManager, typeStrategy: ThumbnailTypeStrategy) {
        self.store = store
        self.typeStrategy = typeStrategy
    }

    func fetchThumbnail(fileID: NodeIdentifier) throws -> Thumbnail {
        let moc = store.backgroundContext
        return try moc.performAndWait {
            let photo = try store.fetchPhoto(id: fileID, moc: moc)
            return try getThumbnail(from: photo.photoRevision)
        }
    }

    private func getThumbnail(from revision: PhotoRevision) throws -> Thumbnail {
        guard revision.uploadState != .created else {
            throw ThumbnailLoaderError.thumbnailNotYetCreated
        }
        let type = typeStrategy.getType()
        guard let thumbnail = revision.thumbnails.first(where: { $0.type == type }) else {
            throw ThumbnailLoaderError.nonRecoverable
        }
        return thumbnail
    }
}
