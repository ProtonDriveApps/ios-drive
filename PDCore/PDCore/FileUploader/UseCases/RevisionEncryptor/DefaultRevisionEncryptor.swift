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

import Foundation
import CoreData

class DefaultRevisionEncryptor: RevisionEncryptor {
    private let blocksEncryptor: RevisionEncryptor
    private let thumbnailEncryptor: RevisionEncryptor
    private let xAttributesEncryptor: RevisionEncryptor
    private let moc: NSManagedObjectContext

    private let queue = OperationQueue(underlyingQueue: .global())

    private var isCancelled = false
    private var isExecuting = false

    init(
        blocksEncryptor: RevisionEncryptor,
        thumbnailEncryptor: RevisionEncryptor,
        xAttributesEncryptor: RevisionEncryptor,
        moc: NSManagedObjectContext
    ) {
        self.blocksEncryptor = blocksEncryptor
        self.thumbnailEncryptor = thumbnailEncryptor
        self.xAttributesEncryptor = xAttributesEncryptor
        self.moc = moc
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true

        let thumbnailEncryptorOperation = ContentRevisionEncryptorOperation(
            revision: draft,
            contentEncryptor: thumbnailEncryptor,
            onError: { _ in })

        let blocksEncryptorOperation = ContentRevisionEncryptorOperation(
            revision: draft,
            contentEncryptor: blocksEncryptor
        ) { [weak self] error in
            guard let self = self, !self.isCancelled else { return }
            self.cancel()
            completion(.failure(error))
        }

        let xAttrEncryptorOperation = ContentRevisionEncryptorOperation(
            revision: draft,
            contentEncryptor: xAttributesEncryptor
        ) { [weak self] error in
            guard let self = self, !self.isCancelled else { return }
            self.cancel()
            completion(.failure(error))
        }

        let finishOperation = BlockOperation { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.finalize(draft: draft, completion: completion)
        }

        xAttrEncryptorOperation.addDependency(blocksEncryptorOperation)
        [thumbnailEncryptorOperation, xAttrEncryptorOperation].forEach(finishOperation.addDependency)
        [thumbnailEncryptorOperation, blocksEncryptorOperation, xAttrEncryptorOperation, finishOperation].forEach(queue.addOperation)
    }

    func cancel() {
        guard !isCancelled else { return }

        isCancelled = true
        queue.cancelAllOperations()
    }

    private func finalize(draft: CreatedRevisionDraft, completion: @escaping Completion) {
        moc.perform {
            do {
                let revision = draft.revision.in(moc: self.moc)
                revision.uploadState = .encrypted

                if let url = revision.uploadableResourceURL {
                    revision.uploadableResourceURL = nil
                    try? FileManager.default.removeItem(at: url)
                }

                try self.moc.saveOrRollback()
                completion(.success)
            } catch {
                completion(.failure(error))
            }
        }
    }
}
