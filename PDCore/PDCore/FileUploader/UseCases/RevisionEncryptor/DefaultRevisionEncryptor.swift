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

final class DefaultRevisionEncryptor: RevisionEncryptor {
    private let blocksEncryptor: RevisionEncryptor
    private let thumbnailEncryptor: RevisionEncryptor
    private let finalizer: RevisionEncryptionFinalizer

    private let queue = OperationQueue(underlyingQueue: .global())

    private var isCancelled = false

    init(
        blocksEncryptor: RevisionEncryptor,
        thumbnailEncryptor: RevisionEncryptor,
        finalizer: RevisionEncryptionFinalizer
    ) {
        self.blocksEncryptor = blocksEncryptor
        self.thumbnailEncryptor = thumbnailEncryptor
        self.finalizer = finalizer
    }

    func encrypt(revisionDraft draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled else { return }
        
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

        let finishOperation = BlockOperation { [weak self] in
            guard let self = self, !self.isCancelled else { return }

            self.finalizer.finalize(revision: draft.revision) { result in
                guard !self.isCancelled else { return }

                switch result {
                case .success:
                    completion(.success)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        [thumbnailEncryptorOperation, blocksEncryptorOperation].forEach(finishOperation.addDependency)
        [thumbnailEncryptorOperation, blocksEncryptorOperation, finishOperation].forEach(queue.addOperation)
    }

    func cancel() {
        guard !isCancelled else { return }

        isCancelled = true
        queue.cancelAllOperations()
    }

}
