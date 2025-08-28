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

struct PhotoFavoriteState: Hashable {
    let id: PhotoId
    let isFavorite: Bool
    let isInPhotoStream: Bool
}

final class FavoritingInteractor: ThrowingAsynchronousInteractor {
    private let localRepository: LocalFavoritingRepositoryProtocol
    private let addFavoriteTagInteractor: AddFavoriteTagInteractorProtocol
    private let removeFavoriteTagInteractor: RemoveFavoriteTagInteractorProtocol

    init(
        localRepository: LocalFavoritingRepositoryProtocol,
        addFavoriteTagInteractor: AddFavoriteTagInteractorProtocol,
        removeFavoriteTagInteractor: RemoveFavoriteTagInteractorProtocol
    ) {
        self.localRepository = localRepository
        self.addFavoriteTagInteractor = addFavoriteTagInteractor
        self.removeFavoriteTagInteractor = removeFavoriteTagInteractor
    }

    func execute(with input: FavoritingInput) async throws -> FavoritingOutput {
        let states = try await localRepository.getStates(ids: input)
        // When mixture of favorited & non-favorited photos is selected, we should mark if at least one of them
        // is non-favorite
        let shouldMarkFavorite = states.contains(where: { !$0.isFavorite })
        // Filter photos that really need the change (discarding those already in desired state)
        let filteredStates = states.filter { $0.isFavorite != shouldMarkFavorite }

        if !shouldMarkFavorite {
            try await removeFavoriteTagInteractor.unmarkFavorite(input: filteredStates)
            return FavoritingOutput.unmarkedFavorite(filteredStates.count)
        } else {
            return try await addFavoriteTagInteractor.markFavorite(input: filteredStates)
        }
    }
}
