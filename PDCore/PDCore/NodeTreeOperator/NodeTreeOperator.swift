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
import Foundation

/// Perform local cache actions for the given node and its children
public struct NodeTreeOperator: Sendable, NodeTreeOperatorProtocol {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func perform(
        actions: [NodeTreeAction],
        onNodes identifiers: [AnyVolumeIdentifier],
        in moc: NSManagedObjectContext
    ) async throws {
        try await moc.perform { [moc] in
            let nodes = Node.fetch(identifiers: Set(identifiers), allowSubclasses: true, in: moc)
            for action in actions {
                switch action {
                case .deleteCached:
                    self.dependencies.cachedRemover.perform(to: nodes)
                case .trashLocally:
                    try self.dependencies.trashHandler.performAndSave(to: nodes, in: moc)
                }
            }
        }
    }

    /// Must run this function inside NSManagedObjectContext
    public func performDeleteLocalCached(on nodes: [Node]) {
        dependencies.cachedRemover.perform(to: nodes)
    }

    public func handleTrash(on nodes: [Node], in moc: NSManagedObjectContext) {
        dependencies.trashHandler.perform(to: nodes, in: moc)
    }
}

extension NodeTreeOperator {
    public struct Dependencies: @unchecked Sendable {
        let cachedRemover: NodeTreeCacheFileRemoverProtocol
        let trashHandler: NodeTreeTrashHandlerProtocol

        public init(
            cachedRemover: NodeTreeCacheFileRemoverProtocol = NodeTreeCacheFileRemover(),
            trashHandler: NodeTreeTrashHandlerProtocol
        ) {
            self.cachedRemover = cachedRemover
            self.trashHandler = trashHandler
        }
    }
}
