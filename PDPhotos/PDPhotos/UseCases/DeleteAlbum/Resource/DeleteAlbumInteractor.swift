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

import CoreData
import PDCore

protocol DeleteAlbumInteractorProtocol {
    func execute(albumID: AnyVolumeIdentifier, deleteAlbumPhotos: Bool) async throws
}

struct DeleteAlbumInteractor: DeleteAlbumInteractorProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(albumID: AnyVolumeIdentifier, deleteAlbumPhotos: Bool) async throws {
        Log.info("Deleting album: should delete album photos: \(deleteAlbumPhotos)", domain: .albums)
        try await dependencies.client.deleteAlbum(
            parameters: .init(
                volumeID: albumID.volumeID,
                linkID: albumID.id,
                deleteAlbumPhotos: deleteAlbumPhotos
            )
        )
        Log.info("Deleting album: cleaning up local state", domain: .albums)
        try await deleteLocalAlbum(albumID: albumID)
    }

    private func deleteLocalAlbum(albumID: AnyVolumeIdentifier) async throws {
        let context = dependencies.managedObjectContext
        try await context.perform {
            guard let album = CoreDataAlbum.fetch(identifier: albumID, in: context) else {
                return
            }
            context.delete(album)
            try context.save()
        }
    }
}

extension DeleteAlbumInteractor {
    struct Dependencies {
        let client: AlbumAPIService
        let managedObjectContext: NSManagedObjectContext
    }
}
