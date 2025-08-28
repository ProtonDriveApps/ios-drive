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
    private let queue: OperationQueue
    private var operationsContainer = OperationsContainer()

    private var isCancelled = false
    private var isExecuting = false

    init(
        blocksEncryptor: RevisionEncryptor,
        thumbnailEncryptor: RevisionEncryptor,
        xAttributesEncryptor: RevisionEncryptor,
        moc: NSManagedObjectContext,
        queue: OperationQueue = OperationQueue(underlyingQueue: .global(qos: .userInitiated))
    ) {
        self.blocksEncryptor = blocksEncryptor
        self.thumbnailEncryptor = thumbnailEncryptor
        self.xAttributesEncryptor = xAttributesEncryptor
        self.moc = moc
        self.queue = queue
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true

        if draft.isEmpty {
            Log.info("STAGE: 1 🏞📦🏜️ Encrypt revision finished ✅. UUID: \(draft.uploadID)", domain: .uploader)

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

            finishOperation.addDependency(xAttrEncryptorOperation)
            let operations = [xAttrEncryptorOperation, finishOperation]
            operationsContainer.set(operations: operations)
            queue.addOperations(operations, waitUntilFinished: false)
        } else {
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
            let operations = [thumbnailEncryptorOperation, blocksEncryptorOperation, xAttrEncryptorOperation, finishOperation]
            operationsContainer.set(operations: operations)
            queue.addOperations(operations, waitUntilFinished: false)
        }
    }

    func cancel() {
        operationsContainer.cancelAllOperations()
        isCancelled = true
    }

    private func finalize(draft: CreatedRevisionDraft, completion: @escaping Completion) {
        moc.perform { [weak self] in
            guard let self, !self.isCancelled else { return }
            do {
                let revision = draft.revision.in(moc: self.moc)
                revision.uploadState = .encrypted

                revision.clearUnencryptedContents()
                revision.normalizedUploadableResourceURL = nil

                try self.moc.saveOrRollback()
                Log.info("Switched revision.uploadState to .encrypted. UUID: \(draft.uploadID)", domain: .uploader)
                completion(.success)
            } catch {
                completion(.failure(error))
            }
        }
    }
}
