// Copyright (c) 2023 Proton AG
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

protocol ThumbnailURLFetchInteractor {
    func execute(thumbnailId: String, volumeId: String) async throws -> URL
}

enum ThumbnailURLFetchInteractorError: Error {
    case invalidResponse
}

final class RemoteThumbnailURLFetchInteractor: ThumbnailURLFetchInteractor {
    private let listInteractor: ThumbnailsListInteractor
    private let updateRepository: ThumbnailsUpdateRepository

    init(listInteractor: ThumbnailsListInteractor, updateRepository: ThumbnailsUpdateRepository) {
        self.listInteractor = listInteractor
        self.updateRepository = updateRepository
    }

    func execute(thumbnailId: String, volumeId: String) async throws -> URL {
        let urls = try await listInteractor.execute(ids: [thumbnailId], volumeId: volumeId)
        try updateRepository.update(thumbnails: urls)
        guard let url = urls.first else {
            throw ThumbnailURLFetchInteractorError.invalidResponse
        }
        return url.url
    }
}
