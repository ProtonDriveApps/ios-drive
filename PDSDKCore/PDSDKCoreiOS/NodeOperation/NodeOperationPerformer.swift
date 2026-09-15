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
}

// MARK: - Device
extension NodeOperationPerformer {
    public func renameDevice(identifier: DeviceIdentifier, newName: String) async throws {
        try await dependencies.performer.renameDevice(
            identifier: identifier,
            newName: newName,
            cancellationToken: UUID(),
            moc: dependencies.context
        )
    }
}

extension NodeOperationPerformer {
    // The SDK groups nodes by volume ID, so file and photo nodes share one performer per operation type.
    public func trash(nodes: [AnyVolumeIdentifier]) -> AsyncThrowingStream<SDKNodeOperationStreamEvent, Error> {
        nodeOperationStream(label: "Trash", nodes: nodes) { nodes, token, moc in
            dependencies.performer.trash(nodes: nodes.map(\.sdkUid), cancellationToken: token, moc: moc)
        }
    }

    public func delete(nodes: [AnyVolumeIdentifier]) -> AsyncThrowingStream<SDKNodeOperationStreamEvent, Error> {
        nodeOperationStream(label: "Delete", nodes: nodes) { nodes, token, moc in
            dependencies.performer.delete(nodes: nodes.map(\.sdkUid), cancellationToken: token, moc: moc)
        }
    }

    public func restore(nodes: [AnyVolumeIdentifier]) -> AsyncThrowingStream<SDKNodeOperationStreamEvent, Error> {
        nodeOperationStream(label: "Restore", nodes: nodes) { nodes, token, moc in
            dependencies.performer.restore(nodes: nodes.map(\.sdkUid), cancellationToken: token, moc: moc)
        }
    }

    public func emptyTrash() async throws {
        let context = dependencies.context
        async let emptyFileTrash = dependencies.performer.emptyTrash(cancellationToken: UUID(), moc: context)
        async let emptyPhotoTrash = dependencies.photoPerformer.emptyTrash(cancellationToken: UUID(), moc: context)
        let _ = try await (emptyFileTrash, emptyPhotoTrash)
    }

    private func nodeOperationStream(
        label: String,
        nodes: [AnyVolumeIdentifier],
        operation: ([AnyVolumeIdentifier], UUID, NSManagedObjectContext) -> AsyncThrowingStream<NodeOperationStreamEvent, Error>
    ) -> AsyncThrowingStream<SDKNodeOperationStreamEvent, Error> {
        Log.debug("\(label) \(nodes.count) nodes", domain: .sdk)
        let inner = operation(nodes, UUID(), context)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in inner {
                        switch event {
                        case .nodeResults(let results, let affectedIdentifiers):
                            continuation.yield(.nodeResults(
                                results: results.map { ($0.nodeUid.any, error: $0.error) },
                                affectedIdentifiers: affectedIdentifiers
                            ))
                        case .completed(let error):
                            continuation.yield(.completed(error: error))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

extension NodeOperationPerformer {
    public struct Dependencies {
        public let performer: FileOperationPerformer
        public let photoPerformer: PhotosOperationPerformer
        public let context: NSManagedObjectContext

        public init(
            performer: FileOperationPerformer,
            photoPerformer: PhotosOperationPerformer,
            context: NSManagedObjectContext
        ) {
            self.performer = performer
            self.photoPerformer = photoPerformer
            self.context = context
        }
    }
}

