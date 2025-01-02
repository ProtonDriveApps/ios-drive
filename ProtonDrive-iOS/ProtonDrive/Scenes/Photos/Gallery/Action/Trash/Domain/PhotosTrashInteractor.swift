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

import PDCore

final class PhotosTrashInteractor: ThrowingAsynchronousInteractor {
    private let remoteRepository: RemotePhotosTrashRepository
    private let localRepository: LocalPhotosTrashRepository

    init(remoteRepository: RemotePhotosTrashRepository, localRepository: LocalPhotosTrashRepository) {
        self.remoteRepository = remoteRepository
        self.localRepository = localRepository
    }

    func execute(with input: PhotoIdsSet) async throws {
        let groups = Array(input).splitIntoChunks()
        let trashData = groups.map { PhotosTrashData(volumeId: $0.volume, shareId: $0.share, nodeIds: $0.links) }
        for data in trashData {
            let result = try await remoteRepository.trash(with: data)
            try await localRepository.trash(with: result.trashed.map { NodeIdentifier($0, data.shareId, data.volumeId) })
        }
    }
}
