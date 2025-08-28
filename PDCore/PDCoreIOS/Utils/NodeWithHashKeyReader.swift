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
import PDCore

public protocol DecryptedNodeHashKeyRepository {
    func getDecryptedProperties(
        from identifier: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) async throws -> NodeWithNodeHashKeyProperty
    func getDecryptedProperties(
        from identifier: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) throws -> NodeWithNodeHashKeyProperty
}

public struct NodeWithHashKeyReader: DecryptedNodeHashKeyRepository {

    public init() {}

    /// Switch to context thread to read
    public func getDecryptedProperties(
        from identifier: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) async throws -> NodeWithNodeHashKeyProperty {
        try await context.perform {
            try getDecryptedProperties(from: identifier, in: context)
        }
    }

    /// Will not switch to context thread, use when you already in a context thread
    public func getDecryptedProperties(
        from identifier: AnyVolumeIdentifier,
        in context: NSManagedObjectContext
    ) throws -> NodeWithNodeHashKeyProperty {
        guard
            let node = Node.fetch(identifier: identifier, allowSubclasses: true, in: context),
            let nodeWithHashKey = node as? NodeWithNodeHashKeyProtocol
        else { throw Errors.NodeDoesNotExist }

        return .init(
            nodeKey: node.nodeKey,
            decryptedHashKey: try nodeWithHashKey.decryptNodeHashKey(),
            identifier: identifier
        )
    }

    enum Errors: Error {
        case NodeDoesNotExist
    }
}

public struct NodeWithNodeHashKeyProperty {
    public let nodeKey: String
    public let decryptedHashKey: String
    public let identifier: AnyVolumeIdentifier
}
