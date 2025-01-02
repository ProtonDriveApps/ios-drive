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
        let revisionMeta = try await client.getRevision(revisionID: identifier.revision, fileID: identifier.file, shareID: identifier.share)

        _ = try await performUpdate(in: storage.backgroundContext, revisionIdentifier: identifier, revisionMeta: revisionMeta)
    }

    @discardableResult
    public func performUpdate(
        in context: NSManagedObjectContext,
        revisionIdentifier identifier: RevisionIdentifier,
        revisionMeta: PDClient.Revision
    ) async throws -> (File, Revision) {
        try await context.perform {
            let revision = Revision.fetchOrCreate(identifier: identifier, allowSubclasses: true, in: context)
            revision.fulfill(from: revisionMeta)

            let file = File.fetchOrCreate(identifier: identifier.nodeIdentifier, allowSubclasses: true, in: context)
            file.volumeID = identifier.volumeID

            self.storage.removeOldBlocks(of: revision)

            let newBlocks: [DownloadBlock] = self.storage.unique(with: Set(revisionMeta.blocks.map { $0.URL.absoluteString }), uniqueBy: #keyPath(DownloadBlock.downloadUrl), in: context)

            newBlocks.forEach { block in
                let meta = revisionMeta.blocks.first { $0.URL.absoluteString == block.downloadUrl }!
                block.fulfill(from: meta)
                block.volumeID = identifier.volumeID
                block.setValue(revision, forKey: #keyPath(Block.revision))
            }

            revision.setValue(file, forKey: #keyPath(Revision.file))
            revision.blocks = Set(newBlocks)

            try context.saveOrRollback()

            return (file, revision)
        }
    }
}
