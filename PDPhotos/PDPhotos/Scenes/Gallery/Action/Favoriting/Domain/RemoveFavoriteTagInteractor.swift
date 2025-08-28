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

protocol RemoveFavoriteTagInteractorProtocol {
    func unmarkFavorite(input: [PhotoFavoriteState]) async throws
}

final class RemoveFavoriteTagInteractor: RemoveFavoriteTagInteractorProtocol {
    private let localRepository: LocalFavoritingRepositoryProtocol
    private let remoteRepository: RemoteFavoritingRepositoryProtocol

    init(
        localRepository: LocalFavoritingRepositoryProtocol,
        remoteRepository: RemoteFavoritingRepositoryProtocol
    ) {
        self.localRepository = localRepository
        self.remoteRepository = remoteRepository
    }

    func unmarkFavorite(input: [PhotoFavoriteState]) async throws {
        let ids = input.map(\.id)

        let errors = await withTaskGroup(of: Error?.self) { group in
            for id in ids {
                group.addTask {
                    await self.unmark(id: id)
                }
            }

            var errors: [Error?] = []
            for await result in group {
                errors.append(result)
            }
            return errors.compactMap { $0 }
        }

        if let error = errors.first {
            Log.error("Some items failed to be unmarked as favorite", error: DriveError(withDomainAndCode: error), domain: .albums)
            throw error
        }
    }

    private func unmark(id: AnyVolumeIdentifier) async -> Error? {
        do {
            // Update remote
            try await remoteRepository.removeFavoriteTag(id: id)
            // Update local state
            try await localRepository.toggle(isFavorite: false, ids: [id])
            return nil
        } catch {
            return error
        }
    }
}
