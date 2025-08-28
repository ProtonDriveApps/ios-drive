// Copyright (c) 2024 Proton AG
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

import PDClient

public final class TrashedNodeDeleter {

    private let client: Client
    private let storage: StorageManager

    public init(client: Client, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }

    public func delete(_ nodes: [NodeIdentifier]) async throws {
        Log.info("Deleting trashed by legacy share based endpoint", domain: .clientNetworking)

        let failedItems = try await withThrowingTaskGroup(of: [PartialFailure].self) { tasksGroup in
            for chunk in nodes.splitIntoChunks() {
                tasksGroup.addTask {
                    let result = try await self.deleteTrashed(volumeID: chunk.volume, shareID: chunk.share, linkIDs: chunk.links)
                    try await self.setToBeDeleted(result.deleted)
                    return result.failed
                }
            }
            try await tasksGroup.waitForAll()
            return try await tasksGroup.reduce(into: [PartialFailure]()) {
                $0.append(contentsOf: $1)
            }
        }

        if let failedItemError = failedItems.first?.error {
            throw failedItemError
        }
    }

    public func deletePerVolume(_ ids: [NodeIdentifier]) async throws {
        Log.info("Deleting trashed by volume based endpoint", domain: .clientNetworking)

        let failedItems = try await withThrowingTaskGroup(of: [PartialFailure].self) { tasksGroup in
            for chunk in ids.splitIntoChunksByVolume() {
                tasksGroup.addTask {
                    let result = try await self.deleteTrashed(volumeId: chunk.volumeId, linkIds: chunk.nodeIds)
                    try await self.setToBeDeleted(result.deleted)
                    return result.failed
                }
            }
            try await tasksGroup.waitForAll()
            return try await tasksGroup.reduce(into: [PartialFailure]()) {
                $0.append(contentsOf: $1)
            }
        }

        if let failedItemError = failedItems.first?.error {
            throw failedItemError
        }
    }

    private func deleteTrashed(volumeID: String, shareID: String, linkIDs: [String]) async throws -> (deleted: [AnyVolumeIdentifier], failed: [PartialFailure]) {
        let partialFailures = try await client.deleteTrashed(shareID: shareID, linkIDs: linkIDs)
        let allLinks = Set(linkIDs)
        let failedLinks = Set(partialFailures.map(\.id))
        let deletedLinks = allLinks.subtracting(failedLinks).map { AnyVolumeIdentifier(id: $0, volumeID: volumeID) }
        return (deletedLinks, partialFailures)
    }

    private func setToBeDeleted(_ ids: [AnyVolumeIdentifier]) async throws {
        let context = storage.mainContext

        try await context.perform {
            let nodes = Node.fetch(identifiers: Set(ids), allowSubclasses: true, in: context)
            nodes.forEach { $0.setToBeDeletedRecursivelly() }
            try context.saveOrRollback()
        }
    }

    private func deleteTrashed(volumeId: String, linkIds: [String]) async throws -> (deleted: [AnyVolumeIdentifier], failed: [PartialFailure]) {
        let partialFailures = try await client.deleteTrashed(volumeId: volumeId, linkIds: linkIds)
        let allLinks = Set(linkIds)
        let failedLinks = Set(partialFailures.map(\.id))
        let deletedLinks = allLinks.subtracting(failedLinks).map { AnyVolumeIdentifier(id: $0, volumeID: volumeId) }
        return (deletedLinks, partialFailures)
    }
}
