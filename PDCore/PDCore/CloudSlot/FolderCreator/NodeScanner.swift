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

class NodeScanner {

    private let client: Client
    private let storage: StorageManager

    init(client: Client, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }

    public func scanNode(_ identifier: NodeIdentifier) async throws {
        let context = storage.backgroundContext
        let node = try await client.getNode(shareID: identifier.shareID, nodeID: identifier.nodeID)
        try await context.perform {
            self.storage.updateLink(node, in: context)
            try context.saveOrRollback()
        }
    }

}
