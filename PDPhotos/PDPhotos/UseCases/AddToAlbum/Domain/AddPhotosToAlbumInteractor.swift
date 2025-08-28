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

import PDCore

struct AddPhotosToAlbumInput {
    let albumId: AnyVolumeIdentifier
    let primaryPhotoIds: Set<AnyVolumeIdentifier>
}

struct AddPhotosToAlbumOutput {
    let volumeId: String
    let inputCount: Int
    let result: Result

    enum Result {
        case added(AlbumContentOperationResult)
        case copied(CopyPhotosOutput)
    }
}

/// Adds photos to own album, copies photos to foreign albums
final class AddPhotosToAlbumInteractor: ThrowingAsynchronousInteractor {
    private let albumOwnershipRepository: AlbumOwnershipRepositoryProtocol
    private let addInteractor: AddPhotosToOwnAlbumInteractorProtocol
    private let copyInteractor: CopyPhotosInteractorProtocol

    init(albumOwnershipRepository: AlbumOwnershipRepositoryProtocol, addInteractor: AddPhotosToOwnAlbumInteractorProtocol, copyInteractor: CopyPhotosInteractorProtocol) {
        self.albumOwnershipRepository = albumOwnershipRepository
        self.addInteractor = addInteractor
        self.copyInteractor = copyInteractor
    }

    func execute(with input: AddPhotosToAlbumInput) async throws -> AddPhotosToAlbumOutput {
        let isOwnAlbum = await albumOwnershipRepository.isOwnAlbum(id: input.albumId)
        let result = try await execute(input: input, isOwnAlbum: isOwnAlbum)
        return AddPhotosToAlbumOutput(volumeId: input.albumId.volumeID, inputCount: input.primaryPhotoIds.count, result: result)
    }

    private func execute(input: AddPhotosToAlbumInput, isOwnAlbum: Bool) async throws -> AddPhotosToAlbumOutput.Result {
        if isOwnAlbum {
            let parameters = AddPhotosToOwnAlbumInteractor.Parameters(albumID: input.albumId, primaryIds: Array(input.primaryPhotoIds))
            let result = try await addInteractor.execute(parameters: parameters)
            return .added(result)
        } else {
            let parameters = CopyPhotosInteractor.Parameters(
                primaryIds: input.primaryPhotoIds,
                targetParentId: input.albumId,
                copyToPhotoRoot: false
            )
            let result = try await copyInteractor.execute(parameters: parameters)
            return .copied(result)
        }
    }
}
