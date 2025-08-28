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

import CoreData
import PDClient

// Volume based trasher
final class VolumeNodeTrasher {
    private let client: TrashRepository
    private let localTrasher: LocalNodeTrasherProtocol

    init(client: TrashRepository, localTrasher: LocalNodeTrasherProtocol) {
        self.client = client
        self.localTrasher = localTrasher
    }

    func trash(ids: [AnyVolumeIdentifier]) async throws {
        let failedItems = try await withThrowingTaskGroup(
            of: [PartialFailure].self,
            returning: [PartialFailure].self
        ) { [weak self] tasksGroup in
            guard let self else { return [] }
            let chunks = ids.splitIntoChunksByVolume()
            for chunk in chunks {
                tasksGroup.addTask {
                    let result = try await self.trash(volumeID: chunk.volumeId, linkIDs: chunk.nodeIds)
                    try await self.localTrasher.trashLocally(result.trashed)
                    return result.failed
                }
            }
            var failures: [PartialFailure] = []
            for try await result in tasksGroup {
                failures.append(contentsOf: result)
            }
            return failures
        }
        if let failedItemError = failedItems.first?.error {
            throw failedItemError
        }
    }

    private func trash(
        volumeID: String,
        linkIDs: [String]
    ) async throws -> (trashed: [AnyVolumeIdentifier], failed: [PartialFailure]) {
        let parameters = TrashVolumeLinksParameters(volumeID: volumeID, linkIds: linkIDs)
        let result = try await client.trashVolumeNodes(parameters: parameters, breadcrumbs: .startCollecting())
        let partialFailures = result.responses.compactMap(PartialFailure.init)
        let allLinks = Set(linkIDs)
        let failedLinks = Set(partialFailures.map(\.id))
        let trashedLinks = allLinks.subtracting(failedLinks).map { AnyVolumeIdentifier(id: $0, volumeID: volumeID) }
        return (trashedLinks, partialFailures)
    }
}
