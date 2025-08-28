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
import PDClient

public typealias ThumbnailsList = [ThumbnailURL]
public struct ThumbnailURL: Equatable {
    public let volumeID: String
    public let id: String
    public let url: URL
}

enum ThumbnailsListInteractorError: Error {
    case invalidResponse
}

public protocol ThumbnailsListInteractor {
    func execute(ids: Set<AnyVolumeIdentifier>) async throws -> ThumbnailsList
}

final class RemoteThumbnailsListInteractor: ThumbnailsListInteractor {
    private let repository: ThumbnailsListRepository
    private let maximalIdsCount = 30

    init(repository: ThumbnailsListRepository) {
        self.repository = repository
    }

    func execute(ids: Set<AnyVolumeIdentifier>) async throws -> ThumbnailsList {
        let idsSplitByVolumeId = Array(ids).splitIntoChunksByVolume()
        let results = try await idsSplitByVolumeId.asyncMap { chunk in
            try await execute(ids: chunk.nodeIds, volumeId: chunk.volumeId)
        }
        return results.flatMap { $0 }
    }

    private func execute(ids: [String], volumeId: String) async throws -> ThumbnailsList {
        let batches = ids.splitInGroups(of: maximalIdsCount)
        var result = [ThumbnailInfo]()
        for batch in batches {
            let parameters = GetThumbnailsByIDParameters(volumeID: volumeId, thumbnailIDs: batch)
            let thumbnailsBatch = try await repository.getThumbnails(with: parameters)
            result += thumbnailsBatch
        }
        return try result.map { try makeModel(from: $0, volumeID: volumeId) }
    }

    private func makeModel(from info: ThumbnailInfo, volumeID: String) throws -> ThumbnailURL {
        guard let url = URL(string: info.bareURL + "/" + info.token) else {
            throw ThumbnailsListInteractorError.invalidResponse
        }
        return ThumbnailURL(volumeID: volumeID, id: info.thumbnailID, url: url)
    }
}
