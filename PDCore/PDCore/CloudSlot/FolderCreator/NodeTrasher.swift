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

final class NodeTrasher {

    private let client: Client
    private let storage: StorageManager

    public init(client: Client, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }

    func trash(_ nodes: [TrashingNodeIdentifier]) async throws {
        Log.info("Send to Trash", domain: .networking)

        var requestError: (any Error)?
        var failed = [PartialFailure]()

        do {
            for group in nodes.splitIntoChunks() {
                let groupResult = try await trash(volumeID: group.volume, shareID: group.share, parentID: group.parent, linkIDs: group.links)
                try await trashLocally(groupResult.restored)
                failed.append(contentsOf: groupResult.failed)
            }
        } catch {
            requestError = error
        }

        if let atLeastOneError = requestError ?? failed.first?.error {
            throw atLeastOneError
        }
    }

    private func trash(volumeID: String, shareID: String, parentID: String, linkIDs: [String]) async throws -> (restored: [TrashingNodeIdentifier], failed: [PartialFailure]) {
        let partialFailures = try await client.trash(shareID: shareID, parentID: parentID, linkIDs: linkIDs)
        let allLinks = Set(linkIDs)
        let failedLinks = Set(partialFailures.map(\.id))
        let trashedLinks = allLinks.subtracting(failedLinks).map { TrashingNodeIdentifier(volumeID: volumeID, shareID: shareID, parentID: parentID, nodeID: $0) }
        return (trashedLinks, partialFailures)
    }

    private func trashLocally(_ nodes: [TrashingNodeIdentifier]) async throws {
        let context = storage.backgroundContext

        try await context.perform {
            let nodes = Node.fetch(identifiers: Set(nodes), allowSubclasses: true, in: context)
            nodes.forEach { $0.state = .deleted }
            try context.saveOrRollback()
        }
    }

}
