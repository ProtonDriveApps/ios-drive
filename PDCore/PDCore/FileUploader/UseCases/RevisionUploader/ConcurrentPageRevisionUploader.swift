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

final class ConcurrentPageRevisionUploader: PageRevisionUploader {

    private let page: RevisionPage
    private let moc: NSManagedObjectContext
    private let queue: OperationQueue

    private let contentCreatorOperationFactory: (RevisionPage) -> Operation
    private let blockUploaderOperationFactory: (UploadBlock, FullUploadableBlock) -> Operation
    private let thumbnailUploaderOperationFactory: (Thumbnail, FullUploadableThumbnail) -> Operation

    private var isCancelled = false

    init(
        page: RevisionPage,
        contentCreatorOperationFactory: @escaping (RevisionPage) -> Operation,
        blockUploaderOperationFactory: @escaping (UploadBlock, FullUploadableBlock) -> Operation,
        thumbnailUploaderOperationFactory: @escaping (Thumbnail, FullUploadableThumbnail) -> Operation,
        queue: OperationQueue,
        moc: NSManagedObjectContext
    ) {
        self.page = page
        self.contentCreatorOperationFactory = contentCreatorOperationFactory
        self.blockUploaderOperationFactory = blockUploaderOperationFactory
        self.thumbnailUploaderOperationFactory = thumbnailUploaderOperationFactory
        self.queue = queue
        self.moc = moc
    }

    func upload(completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isCancelled else { return }

        let initialOperations = makeThumbnailUploaderOperations() + makeBlockUploaderOperations(onError: { completion(.failure($0)) })
        queue.addOperations(initialOperations, waitUntilFinished: true)

        guard !isCancelled else { return }

        let contentCreatorOperation = makeContentCreatorOperation()
        queue.addOperations([contentCreatorOperation], waitUntilFinished: true)

        guard !isCancelled else { return }

        let operations = makeThumbnailUploaderOperations() + makeBlockUploaderOperations(onError: { completion(.failure($0)) })
        queue.addOperations(operations, waitUntilFinished: true)

        guard !isCancelled else { return }

        let finalOperation = makeFinishingPageUploadOperation(onSuccess: { completion(.success) })
        queue.addOperations([finalOperation], waitUntilFinished: false)
    }

    func makeThumbnailUploaderOperations() -> [Operation] {
        guard !page.thumbnails.isEmpty else { return [] }

        return moc.performAndWait {
            var operations = [Operation]()
            
            for thumbnail in self.page.thumbnails {
                if let fullUploadableThumbnail = thumbnail.unsafeFullUploadableThumbnail, !thumbnail.isUploaded {
                    operations.append(thumbnailUploaderOperationFactory(thumbnail, fullUploadableThumbnail))
                }   
            }
            return operations
        }
    }

    func makeBlockUploaderOperations(onError: @escaping OnUploadError) -> [Operation] {
        return moc.performAndWait {
            var operations = [Operation]()
            for block in self.page.blocks {
                if let fullUploadableBlock = FullUploadableBlock(block: block), !block.isUploaded {
                    operations.append(blockUploaderOperationFactory(block, fullUploadableBlock))
                } else if UploadableBlock(block: block) != nil {
                    continue
                } else {
                    onError(block.invalidState("The Block is in an invalid state."))
                    operations.append(NonFinishingOperation())
                    break
                }
            }
            return operations
        }
    }

    func makeContentCreatorOperation() -> Operation {
        contentCreatorOperationFactory(page)
    }

    func makeFinishingPageUploadOperation(onSuccess: @escaping () -> Void) -> Operation {
        BlockOperation(block: onSuccess)
    }

    func cancel() {
        isCancelled = true
        queue.cancelAllOperations()
    }
}
