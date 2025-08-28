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

protocol AlbumKeyProviderProtocol {
    func loadAlbumKey(id: AnyVolumeIdentifier) async throws -> (String, String)
}

struct AlbumKeyProvider: AlbumKeyProviderProtocol {
    let context: NSManagedObjectContext

    func loadAlbumKey(id: AnyVolumeIdentifier) async throws -> (String, String) {
        return try await context.perform {
            guard let album = CoreDataAlbum.fetch(identifier: id, in: context) else {
                throw CreateAlbumError.albumDoesNotExist
            }
            let decryptedNodeHashKey = try album.decryptNodeHashKey()
            let nodeKey = album.nodeKey
            return (nodeKey, decryptedNodeHashKey)
        }
    }

    enum CreateAlbumError: Error {
        case albumDoesNotExist
    }
}
