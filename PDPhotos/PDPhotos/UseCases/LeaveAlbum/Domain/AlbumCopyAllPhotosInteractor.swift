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

struct AlbumCopyAllPhotosInput {
    let albumId: AnyVolumeIdentifier
}

protocol AlbumCopyAllPhotosInteractorProtocol {
    func execute(with input: AlbumCopyAllPhotosInput) async throws -> CopyPhotosOutput
}

final class AlbumCopyAllPhotosInteractor: AlbumCopyAllPhotosInteractorProtocol {
    private let fetchInteractor: AlbumAllChildrenInteractorProtocol
    private let copyInteractor: CopyPhotosInteractorProtocol
    private let rootRepository: PhotoVolumeRootFolderIdRepositoryProtocol

    init(fetchInteractor: AlbumAllChildrenInteractorProtocol, copyInteractor: CopyPhotosInteractorProtocol, rootRepository: PhotoVolumeRootFolderIdRepositoryProtocol) {
        self.fetchInteractor = fetchInteractor
        self.copyInteractor = copyInteractor
        self.rootRepository = rootRepository
    }

    func execute(with input: AlbumCopyAllPhotosInput) async throws -> CopyPhotosOutput {
        Log.info("Starting copying all photos to stream", domain: .albums)
        let listings = try await fetchInteractor.fetchAllChildren(albumId: input.albumId)
        Log.info("Copying all album children to stream", domain: .albums)
        let primaryIdentifiers = listings.map(\.primary)
        return try await copy(identifiers: Set(primaryIdentifiers))
    }

    private func copy(identifiers: Set<AnyVolumeIdentifier>) async throws -> CopyPhotosOutput {
        let rootId = try rootRepository.getId()
        let parameters = CopyPhotosInteractor.Parameters(primaryIds: identifiers, targetParentId: rootId, copyToPhotoRoot: true)
        return try await copyInteractor.execute(parameters: parameters)
    }
}
