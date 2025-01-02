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

import CoreData
import PDCore

// Contains same implementation as `Tower`, but that one is deprecated.
final class NodeNameEditor: NodeNameEditorProtocol {
    private let storage: StorageManager
    private let managedObjectContext: NSManagedObjectContext
    private let nodeRenamer: NodeRenamerProtocol

    init(storage: StorageManager, managedObjectContext: NSManagedObjectContext, nodeRenamer: NodeRenamerProtocol) {
        self.storage = storage
        self.managedObjectContext = managedObjectContext
        self.nodeRenamer = nodeRenamer
    }

    func rename(to name: String, node: NodeIdentifier, completion: @escaping (NodeNameEditorProtocol.Result) -> Void) {
        Task {
            do {
                let node = try await renameAsync(name: name, nodeIdentifier: node)
                completion(.success(node))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func renameAsync(name: String, nodeIdentifier: NodeIdentifier) async throws -> Node {
        guard let node = storage.fetchNode(id: nodeIdentifier, moc: managedObjectContext) else {
            throw NSError(domain: "Failed to find Node", code: 0, userInfo: nil)
        }

        let mimeType = makeMimeType(node: node, name: name)
        try await nodeRenamer.rename(node, to: name, mimeType: mimeType)
        return node
    }

    private func makeMimeType(node: Node, name: String) -> String? {
        let isProtonDocument = managedObjectContext.performAndWait {
            (node as? File)?.isProtonDocument ?? false
        }

        if node is Folder {
            return Folder.mimeType
        } else if name.fileExtension().isEmpty || isProtonDocument {
            // Preserve the previous MIME type in case:
            // 1. The user removed it when renaming; or
            // 2. It's a Proton Document, which doesn't have an extension on other platforms
            return nil
        } else {
            return URL(fileURLWithPath: name).mimeType()
        }
    }
}
