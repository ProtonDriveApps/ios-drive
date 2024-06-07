// Copyright (c) 2023 Proton AG
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
import PDCore

protocol UploadBlockUrlDataSource {
    func getBlockUrl(for block: VerifiableBlock) async throws -> URL
}

final class CoreDataUploadBlockUrlDataSource: UploadBlockUrlDataSource {
    private let storage: StorageManager
    private let managedObjectContext: NSManagedObjectContext

    init(storage: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.storage = storage
        self.managedObjectContext = managedObjectContext
    }

    func getBlockUrl(for block: VerifiableBlock) async throws -> URL {
        return try managedObjectContext.performAndWait {
            let revisionId = RevisionIdentifier(share: block.identifier.shareId, file: block.identifier.nodeId, revision: block.identifier.revisionId)
            guard let revision = storage.fetchRevision(id: revisionId, moc: managedObjectContext) else {
                throw UploadVerifierError.missingRevision
            }

            guard let block = revision.unsafeSortedUploadBlocks.first(where: { $0.index == block.index }) else {
                throw UploadVerifierError.missingBlock
            }

            guard let blockURL = block.localUrl else {
                throw UploadVerifierError.missingBlockContent
            }

            return blockURL
        }
    }
}
