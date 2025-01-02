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

import Foundation
import PDClient

public final class TrashedNodeRestorer {

    private let client: Client
    private let storage: StorageManager

    public init(client: Client, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }

    public func restore(_ nodes: [NodeIdentifier]) async throws {
        Log.info("Restore from Trash", domain: .networking)

        var requestError: (any Error)?
        var failed = [PartialFailure]()

        do {
            for group in nodes.splitIntoChunks() {
                let groupResult = try await restore(volumeID: group.volume, shareID: group.share, linkIDs: group.links)
                try await restoreLocally(groupResult.restored)
                failed.append(contentsOf: groupResult.failed)
            }
        } catch {
            requestError = error
        }

        if let atLeastOneError = requestError ?? failed.first?.error {
            throw atLeastOneError
        }
    }

    private func restore(volumeID: String, shareID: String, linkIDs: [String]) async throws -> (restored: [NodeIdentifier], failed: [PartialFailure]) {
        let partialFailures = try await client.retoreTrashNode(shareID: shareID, linkIDs: linkIDs)
        let allLinks = Set(linkIDs)
        let failedLinks = Set(partialFailures.map(\.id))
        let restoredLinks = allLinks.subtracting(failedLinks).map { NodeIdentifier($0, shareID, volumeID) }
        return (restoredLinks, partialFailures)
    }

    private func restoreLocally(_ nodes: [NodeIdentifier]) async throws {
        let context = storage.mainContext

        try await context.perform {
            let nodes = Node.fetch(identifiers: Set(nodes), allowSubclasses: true, in: context)
            nodes.forEach { $0.state = .active }
            try context.saveOrRollback()
        }
    }

}
