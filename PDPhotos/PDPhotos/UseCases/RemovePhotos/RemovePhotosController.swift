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
import PDLocalization

protocol RemovePhotosControllerProtocol {
    func execute(ids: PhotoIdsSet) async throws
}

final class RemovePhotosController: RemovePhotosControllerProtocol {
    private let albumID: AnyVolumeIdentifier
    private let batchSize = 10
    private let dependencies: Dependencies

    init(albumID: AnyVolumeIdentifier, dependencies: Dependencies) {
        self.albumID = albumID
        self.dependencies = dependencies
    }

    func execute(ids: PhotoIdsSet) async throws {
        let batches = ids.map(\.id).splitInGroups(of: 10)
        let successIDs = await withTaskGroup(
            of: Result<[String], Error>.self,
            returning: [String].self
        ) { [weak self] group in
            guard let self else { return [] }
            for batch in batches {
                group.addTask {
                    do {
                        let response = try await self.dependencies.client.removePhotosFromAlbum(
                            volumeID: self.albumID.volumeID,
                            linkID: self.albumID.id,
                            photoLinkIDs: batch
                        )
                        let successIDs = self.check(response: response, mainPhotoIDs: batch)
                        return .success(successIDs)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var successIDs: [String] = []
            for await result in group {
                switch result {
                case .success(let ids):
                    successIDs.append(contentsOf: ids)
                case .failure(let error):
                    Log.error("Remove photos from album failed", error: error, domain: .albums)
                }
            }
            return successIDs
        }
        let result = AlbumContentOperationResult(
            failure: ids.count - successIDs.count,
            success: successIDs.count,
            duplication: 0,
            incomplete: 0
        )
        dependencies.albumContentOperationMessenger.showRemovePhotosBanner(for: result)
        try await updateCoreData(success: successIDs)
    }

    // Identify photo IDs that were successfully removed
    private func check(response: RemovePhotosFromAlbumResponse, mainPhotoIDs: [String]) -> [String] {
        var success: [String] = []
        for result in response.responses {
            guard mainPhotoIDs.contains(result.linkID) else { continue }
            if result.response.code == 1000 {
                success.append(result.linkID)
            }
        }
        return success
    }

    private func updateCoreData(success: [String]) async throws {
        let ids = success.map { AnyVolumeIdentifier(id: $0, volumeID: albumID.volumeID) }
        try await dependencies.repository.remove(listing: Set(ids), from: albumID.id)
    }
}

extension RemovePhotosController {
    struct Dependencies {
        let client: AlbumPhotosAPIService
        let repository: DeletePhotoListingsRepository
        let albumContentOperationMessenger: PhotosMoveOperationMessageHandlerProtocol
    }
}
