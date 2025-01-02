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
        var requestError: (any Error)?
        var failed = [PartialFailure]()

        do {
            for group in nodes.splitIntoChunks() {
                let groupResult = try await deleteTrashed(volumeID: group.volume, shareID: group.share, linkIDs: group.links)
                try await setToBeDeleted(groupResult.deleted)
                failed.append(contentsOf: groupResult.failed)
            }
        } catch {
            requestError = error
        }

        if let atLeastOneError = requestError ?? failed.first?.error {
            throw atLeastOneError
        }
    }

    private func deleteTrashed(volumeID: String, shareID: String, linkIDs: [String]) async throws -> (deleted: [NodeIdentifier], failed: [PartialFailure]) {
         let partialFailures = try await client.deleteTrashed(shareID: shareID, linkIDs: linkIDs)
         let allLinks = Set(linkIDs)
         let failedLinks = Set(partialFailures.map(\.id))
         let deletedLinks = allLinks.subtracting(failedLinks).map { NodeIdentifier($0, shareID, volumeID) }
         return (deletedLinks, partialFailures)
     }

    private func setToBeDeleted(_ nodes: [NodeIdentifier]) async throws {
        let context = storage.mainContext

        try await context.perform {
            let nodes = Node.fetch(identifiers: Set(nodes), allowSubclasses: true, in: context)
            nodes.forEach { $0.setToBeDeletedRecursivelly() }
            try context.saveOrRollback()
        }
    }

}
