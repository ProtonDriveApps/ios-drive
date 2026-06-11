// Copyright (c) 2026 Proton AG
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
import PDSDKCore
import PDCore

public final class NodeOperationPerformer: SDKNodeOperationPerformer {
    private let dependencies: Dependencies
    private var context: NSManagedObjectContext { dependencies.context }

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func rename(nodeUid: AnyVolumeIdentifier, newName: String) async throws -> Node {
        let validatedName = try newName.validateNodeName(validator: NameValidations.iosName)
        let (node, isProtonFile) = try await context.perform { [context] in
            let node = try Node.fetch(identifier: nodeUid, allowSubclasses: true, in: context) ?! "Can't reterive node"
            let isProtonFile = (node as? File)?.isProtonFile ?? false
            return (node, isProtonFile)
        }

        let newMime: String?
        if node is Folder {
            newMime = Folder.mimeType
        } else if validatedName.fileExtension.isEmpty || isProtonFile {
            // Preserve the previous MIME type in case:
            // 1. The user removed it when renaming; or
            // 2. It's a Proton Document, which doesn't have an extension on other platforms
            newMime = nil
        } else {
            newMime = URL(fileURLWithPath: validatedName).mimeType()
        }

        try await dependencies.performer.rename(
            nodeUid: nodeUid.sdkUid,
            newName: validatedName,
            newMediaType: newMime,
            cancellationToken: UUID(),
            moc: context
        )
        return node
    }

    public func createFolder(parentFolderID: AnyVolumeIdentifier, name: String) async throws -> CoreDataFolder {
        let validatedName = try name.validateNodeName(validator: NameValidations.iosName)
        return try await dependencies.performer.createFolder(
            parentFolderUid: parentFolderID.sdkUid,
            folderName: validatedName,
            lastModificationTime: Date(),
            resolveConflictByRenaming: false,
            moc: dependencies.context,
            cancellationToken: UUID()
        )
    }

    public func trash(nodes: [AnyVolumeIdentifier]) async throws -> ([AnyVolumeIdentifier], Error?) {
        Log.debug("Trash \(nodes.count) nodes", domain: .sdk)
        return try await dependencies.performer.trash(
            nodes: nodes.map { $0.sdkUid },
            cancellationToken: UUID(),
            moc: context
        )
    }
}

extension NodeOperationPerformer {
    public struct Dependencies {
        public let performer: FileOperationPerformer
        public let context: NSManagedObjectContext

        public init(performer: FileOperationPerformer, context: NSManagedObjectContext) {
            self.performer = performer
            self.context = context
        }
    }
}
