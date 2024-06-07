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
    private var operationsContainer = OperationsContainer()

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

        Log.info("ConcurrentPageRevisionUploader 0️⃣ started", domain: .uploader)
        executeFirstStep(completion: completion)
    }

    private func executeFirstStep(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let initialOperations = makeThumbnailUploaderOperations() + (try makeBlockUploaderOperations())
            let creatorOperation = makeContentCreatorOperation()
            creatorOperation.addDependencies(initialOperations)
            let firstStepBarrierOperation = makeFirstStepBarrierOperation(completion: completion)
            firstStepBarrierOperation.addDependency(creatorOperation)
            addOperations(initialOperations + [creatorOperation, firstStepBarrierOperation])
        } catch {
            Log.info("ConcurrentPageRevisionUploader ❌ completed with error", domain: .uploader)
            completion(.failure(error))
        }
    }

    private func makeFirstStepBarrierOperation(completion: @escaping (Result<Void, Error>) -> Void) -> Operation {
        BlockOperation { [weak self] in
            guard let self, !self.isCancelled else { return }
            Log.info("ConcurrentPageRevisionUploader 1️⃣ first step completed", domain: .uploader)
            self.executeSecondStep(completion: completion)
        }
    }

    private func executeSecondStep(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let secondaryOperations = makeThumbnailUploaderOperations() + (try makeBlockUploaderOperations())
            let finishOperation = makeFinishingPageUploadOperation(completion: completion)
            finishOperation.addDependencies(secondaryOperations)
            addOperations(secondaryOperations + [finishOperation])
        } catch {
            Log.info("ConcurrentPageRevisionUploader ❌ completed with error", domain: .uploader)
            completion(.failure(error))
        }
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

    func makeBlockUploaderOperations() throws -> [Operation] {
        return try moc.performAndWait {
            var operations = [Operation]()
            for block in self.page.blocks {

                // Uploaded blocks
                guard !block.isUploaded else { continue }

                let hash = block.sha256.base64EncodedString()
                guard let localURL = block.localUrl else { throw block.invalidState("UploadBlock does not have local URL.") }
                guard let encSignature = block.encSignature else { throw block.invalidState("UploadBlock does not have an encrypted signature.") }
                guard let signatureEmail = block.signatureEmail else { throw block.invalidState("UploadBlock does not have a signature address.") }

                let verificationToken = try page.verification.verificationTokenForBlock(at: block.index)

                let uploadableBlock = UploadableBlock(
                    index: block.index,
                    size: block.size,
                    hash: hash,
                    localURL: localURL,
                    signatureEmail: signatureEmail,
                    encryptedSignature: encSignature,
                    verificationToken: verificationToken
                )

                // The block has requested an uploadURL and a token
                guard let remoteURLString = block.uploadUrl,
                      let remoteURL = URL(string: remoteURLString),
                      let uploadToken = block.uploadToken  else { continue }

                let fullUploadableBlock = FullUploadableBlock(remoteURL: remoteURL, uploadToken: uploadToken, uploadable: uploadableBlock)

                operations.append(blockUploaderOperationFactory(block, fullUploadableBlock))
            }
            return operations
        }
    }
    
    func uploadFinished() -> Bool {
        return moc.performAndWait {
            page.blocks.count == page.blocks.filter { $0.isUploaded }.count &&
            page.thumbnails.count == page.thumbnails.filter { $0.isUploaded }.count
        }
    }

    func makeContentCreatorOperation() -> Operation {
        contentCreatorOperationFactory(page)
    }

    func makeFinishingPageUploadOperation(completion: @escaping (Result<Void, Error>) -> Void) -> Operation {
        BlockOperation { [weak self] in
            guard let self, !self.isCancelled else { return }
            self.finish(completion: completion)
        }
    }

    private func finish(completion: @escaping (Result<Void, Error>) -> Void) {
        Log.info("ConcurrentPageRevisionUploader 2️⃣ finishing", domain: .uploader)
        guard uploadFinished() else {
            return completion(.failure(PageFinishedWithRetriableErrors()))
        }
        completion(.success)
    }

    private func addOperations(_ operations: [Operation]) {
        queue.addOperations(operations, waitUntilFinished: false)
        operationsContainer.set(operations: operations)
    }

    func cancel() {
        Log.info("ConcurrentPageRevisionUploader ⏹️ cancelled", domain: .uploader)
        isCancelled = true
        operationsContainer.cancelAllOperations()
    }

    deinit {
        Log.info("ConcurrentPageRevisionUploader ⏹️ deinit", domain: .uploader)
        operationsContainer.cancelAllOperations()
    }
}

struct PageFinishedWithRetriableErrors: Error { }
