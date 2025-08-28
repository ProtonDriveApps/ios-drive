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
import ProtonCoreNetworking

protocol DeleteAlbumControllerProtocol {
    func execute(parameters: DeleteAlbumController.Parameters) async throws
}

final class DeleteAlbumController: DeleteAlbumControllerProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(parameters: Parameters) async throws {
        try await movePhotosIfNecessary(ids: parameters.photoIDsNeedToBeMoved)
        do {
            try await deleteAlbum(albumId: parameters.albumID, deleteAlbumPhotos: parameters.deleteAlbumPhotos)
        } catch let error as ResponseError where error.responseCode == 200302 {
            try await handleSoftDeleteError(error: error, parameters: parameters)
        } catch {
            throw error
        }
    }

    private func handleSoftDeleteError(error: ResponseError, parameters: Parameters) async throws {
        let linkIds = try dependencies.errorParser.parseChildIds(from: error)
        let passedIds = parameters.photoIDsNeedToBeMoved.map(\.id)
        if Set(passedIds).isSuperset(of: linkIds) {
            // All were moved or filtered by duplicate check.
            // We can delete now with `deleteAlbumPhotos: true`
            Log.info("Soft deleting album: all photos have been moved, retrying with force delete", domain: .albums)
            try await deleteAlbum(albumId: parameters.albumID, deleteAlbumPhotos: true)
        } else {
            // Some photos need to be moved. User needs to be notified
            let remainingIds = Set(linkIds).subtracting(passedIds)
            Log.info("Soft deleting album: failed, need to fetch and move remaining photos", domain: .albums)
            throw DeleteAlbumErrors.containsDirectChildren(linkIds: remainingIds)
        }
    }

    private func deleteAlbum(albumId: AnyVolumeIdentifier, deleteAlbumPhotos: Bool) async throws {
        try await dependencies.interactor.execute(
            albumID: albumId,
            deleteAlbumPhotos: deleteAlbumPhotos
        )
    }

    private func movePhotosIfNecessary(ids: Set<AnyVolumeIdentifier>) async throws {
        guard !ids.isEmpty else {
            return
        }

        Log.info("Moving photos before deleting album: fetch local metadata", domain: .albums)
        let context = dependencies.context
        let photos = await context.perform {
            return CoreDataPhoto.fetch(identifiers: ids, in: context)
        }
        if photos.count != ids.count {
            Log.info("Moving photos before deleting album: We don't have all photos in local DB, need to refetch", domain: .albums)
            throw DeleteAlbumErrors.photoNotFound
        }
        Log.info("Moving photos before deleting album: performing duplicate check", domain: .albums)
        let (root, _, _) = try await dependencies.photoRootProvider.getPhotosRootAndKey()
        let nonDuplicatedPhotos = try await dependencies.duplicatesCheckInteractor.execute(
            nodes: photos,
            photoRoot: root
        )
        // Transferring photos accepts only primary photo. It includes all secondary automatically.
        let mainPhotos = await context.perform {
            nonDuplicatedPhotos.filter { $0.parent == nil }
        }
        Log.info("Moving photos before deleting album: transfer photos, non duplicate main photos count: \(mainPhotos.count)", domain: .albums)
        try await dependencies.multipleNodeTransferrer.move(photos: mainPhotos, to: root)
    }
}

extension DeleteAlbumController {
    struct Dependencies {
        let context: NSManagedObjectContext
        let duplicatesCheckInteractor: SimplePhotoDuplicatesCheckInteractorProtocol
        let interactor: DeleteAlbumInteractorProtocol
        let multipleNodeTransferrer: MultiplePhotoTransferProtocol
        let photoRootProvider: PhotoRootInfoProviderProtocol
        let errorParser: RemoteDeleteAlbumErrorParserProtocol
    }

    struct Parameters {
        let albumID: AnyVolumeIdentifier
        let deleteAlbumPhotos: Bool
        let photoIDsNeedToBeMoved: Set<AnyVolumeIdentifier>
    }
}

enum DeleteAlbumErrors: Error, Equatable {
    case photoNotFound
    case containsDirectChildren(linkIds: Set<String>)
}
