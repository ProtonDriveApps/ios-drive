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
import CoreData

public class RevisionScanner {

    private let client: Client
    private let storage: StorageManager

    public init(client: Client, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }
    
    public func scanRevision(_ identifier: RevisionIdentifier) async throws {
        let revisionMeta = try await client.getRevision(revisionID: identifier.revisionID, fileID: identifier.fileID, shareID: identifier.shareID)

        _ = try await Self.performUpdate(in: storage.backgroundContext, revisionIdentifier: identifier, revisionMeta: revisionMeta, storage: storage)
    }

    @discardableResult
    public static func performUpdate(
        in context: NSManagedObjectContext,
        revisionIdentifier identifier: RevisionIdentifier,
        revisionMeta: PDClient.Revision,
        storage: StorageManager
    ) async throws -> (File, Revision) {
        try await context.perform {
            let revision = Revision.fetchOrCreate(identifier: identifier, allowSubclasses: true, in: context)
            revision.fulfillRevision(with: revisionMeta)

            let file = File.fetchOrCreate(identifier: identifier.nodeIdentifier, allowSubclasses: true, in: context)
            file.volumeID = identifier.volumeID

#if os(iOS)
            for meta in revisionMeta.blocks {
                let block = Self.fetchOrCreateBlock(from: revision, index: meta.index, context: context)
                block.fulfillBlock(with: meta)
                block.volumeID = identifier.volumeID
                revision.addToBlocks(block)
            }
            file.revisions
                .filter { $0 !== revision }
                .forEach {
                    storage.removeOutdatedCache(of: $0)
                    context.delete($0)
                }
            file.addToRevisions(revision)
#else
            storage.removeOutdatedCache(of: revision)

            let newBlocks: [DownloadBlock] = storage.unique(with: Set(revisionMeta.blocks.map { $0.URL.absoluteString }), uniqueBy: #keyPath(DownloadBlock.downloadUrl), in: context)

            newBlocks.forEach { block in
                let meta = revisionMeta.blocks.first { $0.URL.absoluteString == block.downloadUrl }!
                block.fulfillBlock(with: meta)
                block.volumeID = identifier.volumeID
                block.setValue(revision, forKey: #keyPath(Block.revision))
            }
            revision.setValue(file, forKey: #keyPath(Revision.file))
            revision.blocks = Set(newBlocks)
#endif

            try context.saveOrRollback()

            return (file, revision)
        }
    }
    
    private static func fetchOrCreateBlock(from revision: Revision, index: Int, context: NSManagedObjectContext) -> DownloadBlock {
        if let block = revision.blocks.first(where: { $0.index == index }) as? DownloadBlock {
            return block
        } else {
            let block = DownloadBlock(context: context)
            block.index = index
            return block
        }
    }
}
