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

public final class TrashCleaner {

    private let client: Client
    private let storage: StorageManager

    public init(client: Client, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }

    public func emptyTrash(_ nodes: [NodeIdentifier]) async throws {
        Log.info("Empty Trash", domain: .networking)

        var tasks = [Task<Void, Error>]()

        for group in nodes.splitIntoChunks() {
            let task = Task {
                try await client.emptyTrash(shareID: group.share)
                try await setToBeDeleted(group.links.map { NodeIdentifier($0, group.share, group.volume) })
            }
            tasks.append(task)
        }

        for task in tasks {
            try await task.value
        }
    }

    private func setToBeDeleted(_ nodes: [NodeIdentifier]) async throws {
        let context = storage.mainContext

        try await context.perform {
            let nodes = Node.fetch(identifiers: Set(nodes), allowSubclasses: true, in: context)
            nodes.forEach {
                $0.setToBeDeletedRecursivelly()
            }
            try context.saveOrRollback()
        }
    }
}
