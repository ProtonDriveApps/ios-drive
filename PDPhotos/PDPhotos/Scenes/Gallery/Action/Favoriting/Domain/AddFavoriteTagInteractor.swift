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

protocol AddFavoriteTagInteractorProtocol {
    func markFavorite(input: [PhotoFavoriteState]) async throws -> FavoritingOutput
}

final class AddFavoriteTagInteractor: AddFavoriteTagInteractorProtocol {
    private struct AlbumItemsResult {
        let marked: Int
        let skipped: Int

        static let empty = AlbumItemsResult(marked: 0, skipped: 0)
    }

    private let localRepository: LocalFavoritingRepositoryProtocol
    private let remoteRepository: RemoteFavoritingRepositoryProtocol
    private let parametersFactory: FavoritingAlbumPhotoParametersFactoryProtocol
    private let duplicateCheckRepository: PhotosDuplicateCheckRepository

    init(
        localRepository: LocalFavoritingRepositoryProtocol,
        remoteRepository: RemoteFavoritingRepositoryProtocol,
        parametersFactory: FavoritingAlbumPhotoParametersFactoryProtocol,
        duplicateCheckRepository: PhotosDuplicateCheckRepository
    ) {
        self.localRepository = localRepository
        self.remoteRepository = remoteRepository
        self.parametersFactory = parametersFactory
        self.duplicateCheckRepository = duplicateCheckRepository
    }

    func markFavorite(input: [PhotoFavoriteState]) async throws -> FavoritingOutput {
        let streamStates = Set(input.filter { $0.isInPhotoStream })
        let albumStates = Set(input).subtracting(streamStates)

        let streamIds = Set(streamStates.map(\.id))
        try await markStreamItems(ids: streamIds)

        let albumIds = Set(albumStates.map(\.id))
        let albumsResult = try await markAlbumItems(ids: albumIds)

        let output = FavoritingOutput.MarkedFavorite(
            streamPhotos: streamIds.count,
            skipped: albumsResult.skipped,
            copiedToStream: albumsResult.marked
        )
        return .markedFavorite(output)
    }

    private func markStreamItems(ids: Set<AnyVolumeIdentifier>) async throws {
        guard !ids.isEmpty else {
            return
        }

        let errors = await withTaskGroup(of: Error?.self) { group in
            for id in ids {
                group.addTask {
                    await self.markStreamItem(id: id)
                }
            }

            var errors: [Error?] = []
            for await result in group {
                errors.append(result)
            }
            return errors.compactMap { $0 }
        }

        if let error = errors.first {
            Log.error("Some items failed to be marked as favorite", error: DriveError(withDomainAndCode: error), domain: .albums)
            throw error
        }
    }

    private func markStreamItem(id: AnyVolumeIdentifier) async -> Error? {
        do {
            // Update remote state
            try await remoteRepository.markStreamPhotoFavorite(id: id)
            // Update local state
            try await localRepository.toggle(isFavorite: true, ids: [id])
            return nil
        } catch {
            return error
        }
    }

    private func markAlbumItems(ids: Set<AnyVolumeIdentifier>) async throws -> AlbumItemsResult {
        guard !ids.isEmpty else {
            return AlbumItemsResult.empty
        }

        // Filter by duplicate check against photo stream
        let filteredIds = try await duplicateCheckRepository.filterAgainstPhotoRoot(photoIdentifiers: ids)

        let errors = await withTaskGroup(of: Error?.self) { group in
            for id in filteredIds {
                group.addTask {
                    await self.markAlbumItem(id: id)
                }
            }

            var errors: [Error?] = []
            for await result in group {
                errors.append(result)
            }
            return errors.compactMap { $0 }
        }

        if let error = errors.first {
            Log.error("Some items failed to be marked as favorite", error: DriveError(withDomainAndCode: error), domain: .albums)
            throw error
        }

        return AlbumItemsResult(
            marked: filteredIds.count,
            skipped: ids.count - filteredIds.count
        )
    }

    private func markAlbumItem(id: AnyVolumeIdentifier) async -> Error? {
        do {
            // Update remote
            let body = try await parametersFactory.makeParameters(for: id)
            try await remoteRepository.markAlbumPhotoFavorite(id: id, body: body)
            return nil
        } catch {
            return error
        }
    }
}
