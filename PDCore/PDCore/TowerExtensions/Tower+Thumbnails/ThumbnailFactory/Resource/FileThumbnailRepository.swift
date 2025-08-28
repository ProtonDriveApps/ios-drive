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

final class FileNodeThumbnailRepository: NodeThumbnailRepository {
    private let store: StorageManager

    init(store: StorageManager) {
        self.store = store
    }

    func fetchThumbnail(fileID: any VolumeIdentifiable) throws -> Thumbnail {
        let moc = store.backgroundContext

        return try moc.performAndWait {
            guard let file = File.fetch(identifier: fileID, in: moc) else {
                throw ThumbnailLoaderError.nonRecoverable
            }

            guard let revision = file.latestRevision else {
                throw ThumbnailLoaderError.noValidRevision
            }

            return try getThumbnail(from: revision)
        }
    }

    private func getThumbnail(from revision: Revision) throws -> Thumbnail {
        if revision.uploadState == .created {
            throw ThumbnailLoaderError.thumbnailNotYetCreated
        }

        guard let thumbnail = revision.thumbnails.first else {
            throw ThumbnailLoaderError.nonRecoverable
        }

        return thumbnail
    }
}

private extension File {
    var latestRevision: Revision? {
        if let revision = activeRevision {
            return revision
        } else if let revision = activeRevisionDraft {
            return revision
        } else {
            return nil
        }
    }
}
