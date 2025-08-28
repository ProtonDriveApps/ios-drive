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

import Foundation
import PDCore

protocol DirectChildrenInAlbumFetchInteractorProtocol {
    /// - Parameter identifier: Album identifier
    /// - Parameter children: children identifiers identified by BE which may not be returned via listing (e.g. trashed photos)
    /// - Returns: Photo identifiers of direct children
    func execute(identifier: AnyVolumeIdentifier, children: [AnyVolumeIdentifier]) async throws -> Set<AnyVolumeIdentifier>
}

// Fetch and store all of direct children and its metadata
final class DirectChildrenInAlbumFetchInteractor: DirectChildrenInAlbumFetchInteractorProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(identifier: AnyVolumeIdentifier, children: [AnyVolumeIdentifier]) async throws -> Set<AnyVolumeIdentifier> {
        Log.info("Fetching all direct children of an album", domain: .albums)
        var anchorID: String?
        var photoIdentifiers: Set<AnyVolumeIdentifier> = Set(children)
        while true {
            let result = try await fetchAPageOfDirectChildren(identifier: identifier, anchorID: anchorID)
            photoIdentifiers.formUnion(result.photoIdentifiers)
            anchorID = result.anchorID
            guard result.hasMore else { break }
        }
        _ = try await dependencies.metadataRepository.fetch(identifiers: Array(photoIdentifiers))
        return photoIdentifiers
    }

    private func fetchAPageOfDirectChildren(identifier: AnyVolumeIdentifier, anchorID: String?) async throws -> Result {
        let requestParameters: ListPhotosInAlbumRequest.Parameters = .init(
            volumeID: identifier.volumeID,
            linkID: identifier.id,
            anchorID: anchorID,
            onlyChildren: true
        )
        let remoteList = try await dependencies.listRepository.listPhotosInAlbum(parameters: requestParameters)
        let storeData = StorePhotoListingsData(
            listings: remoteList.photos,
            volumeId: requestParameters.volumeID,
            type: .album(albumId: requestParameters.linkID),
            isResetting: false
        )
        try await dependencies.storeListingRepository.storeListings(data: storeData)
        // Ids of all photos, including related photos
        let ids = remoteList.photos
            .flatMap { compound in
                [compound.linkID] + (compound.relatedPhotos ?? []).map(\.linkID)
            }
            .map { AnyVolumeIdentifier(id: $0, volumeID: requestParameters.volumeID) }
        return .init(
            hasMore: remoteList.more,
            anchorID: remoteList.anchorID,
            photoIdentifiers: ids
        )
    }
}

extension DirectChildrenInAlbumFetchInteractor {
    struct Dependencies {
        let listRepository: RemotePhotosListingRepository
        let metadataRepository: RemoteMetadataFetchRepositoryProtocol
        let storeListingRepository: StorePhotoListingsRepository
    }

    struct Result {
        let hasMore: Bool
        let anchorID: String?
        let photoIdentifiers: [AnyVolumeIdentifier]
    }
}
