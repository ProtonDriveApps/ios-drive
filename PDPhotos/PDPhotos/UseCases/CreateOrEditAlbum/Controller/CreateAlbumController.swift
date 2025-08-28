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
import PDClient
import PDCore

protocol CreateAlbumControllerProtocol {
    func execute(parameters: CreateAlbumController.Parameters) async -> CreateAlbumController.Result
}

final class CreateAlbumController: CreateAlbumControllerProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(parameters: Parameters) async -> Result {
        var albumID: AnyVolumeIdentifier?
        do {
            let id = try await createAlbum(name: parameters.clearAlbumName)
            albumID = id
            let result = try await dependencies.addPhotosToAlbumInteractor.execute(
                parameters: AddPhotosToOwnAlbumInteractor.Parameters(
                    albumID: id,
                    primaryIds: parameters.photoIDs
                )
            )
            return .success(id, result)
        } catch {
            if let albumID {
                return .addPhotosFailed(albumID, error)
            } else {
                return .createAlbumFailed(error)
            }
        }
    }

    private func createAlbum(name: String) async throws -> AnyVolumeIdentifier {
        let parameters = CreateAlbumInteractor.Parameters(clearName: name)
        let albumID = try await dependencies.createAlbumInteractor.execute(parameters: parameters)
        return albumID
    }
}

extension CreateAlbumController {
    struct Dependencies {
        let createAlbumInteractor: CreateAlbumInteractorProtocol
        let addPhotosToAlbumInteractor: AddPhotosToOwnAlbumInteractorProtocol
    }

    struct Parameters {
        let clearAlbumName: String
        let photoIDs: [PhotoId]
    }

    enum CreateAlbumError: Error {
        case albumDoesNotExist
    }

    enum Result {
        case createAlbumFailed(Error)
        case addPhotosFailed(AnyVolumeIdentifier, Error)
        case success(AnyVolumeIdentifier, AlbumContentOperationResult)
    }
}
