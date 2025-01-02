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

enum DatabaseThumbnailRepositoryError: Error {
    case invalidStorageState
}

final class DatabaseThumbnailRepository: ThumbnailRepository {
    private let id: ThumbnailIdentifier
    private let storage: StorageManager

    init(id: ThumbnailIdentifier, storage: StorageManager) {
        self.id = id
        self.storage = storage
    }

    func getThumbnail() throws -> Thumbnail {
        let managedObjectContext = storage.backgroundContext
        guard let thumbnail = Thumbnail.fetch(identifier: AnyVolumeIdentifier(id: id.thumbnailId, volumeID: id.volumeId), in: managedObjectContext) else {
            throw DatabaseThumbnailRepositoryError.invalidStorageState
        }
        return thumbnail
    }
}
