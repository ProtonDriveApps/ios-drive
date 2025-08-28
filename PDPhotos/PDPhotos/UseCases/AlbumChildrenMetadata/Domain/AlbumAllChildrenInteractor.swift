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

protocol AlbumAllChildrenInteractorProtocol {
    /// Fetches all children and their metadata
    /// Returns their listings
    func fetchAllChildren(albumId: AnyVolumeIdentifier) async throws -> Set<PhotoListingId>
}

final class AlbumAllChildrenInteractor: AlbumAllChildrenInteractorProtocol {
    private let fetchInteractor: PhotosListFetchingInteractorProtocol
    private let metadataRepository: RemoteMetadataFetchRepositoryProtocol

    init(fetchInteractor: PhotosListFetchingInteractorProtocol, metadataRepository: RemoteMetadataFetchRepositoryProtocol) {
        self.fetchInteractor = fetchInteractor
        self.metadataRepository = metadataRepository
    }

    func fetchAllChildren(albumId: AnyVolumeIdentifier) async throws -> Set<PhotoListingId> {
        Log.info("Fetching all album children", domain: .albums)
        let listings = try await fetchAll(albumId: albumId)
        Log.info("Getting all album children metadata", domain: .albums)
        let allIdentifiers = listings.flatMap(\.allIds)
        _ = try await metadataRepository.fetch(identifiers: allIdentifiers)
        return listings
    }

    private func fetchAll(albumId: AnyVolumeIdentifier) async throws -> Set<PhotoListingId> {
        var anchorId: String?
        var hasMore = false
        var allListings = Set<PhotoListingId>()
        repeat {
            let fetchInput = PhotosListFetchingInput(anchorId: anchorId, tag: nil, isResetting: false)
            let response = try await fetchInteractor.execute(with: fetchInput)
            let listings = response.photos.map { photo in
                PhotoListingId(
                    primary: AnyVolumeIdentifier(id: photo.linkID, volumeID: albumId.volumeID),
                    secondary: (photo.relatedPhotos ?? []).map { secondaryPhoto in
                        AnyVolumeIdentifier(id: secondaryPhoto.linkID, volumeID: albumId.volumeID)
                    }
                )
            }
            allListings.formUnion(listings)
            anchorId = response.anchorId
            hasMore = response.hasMore
        } while hasMore
        return allListings
    }
}
