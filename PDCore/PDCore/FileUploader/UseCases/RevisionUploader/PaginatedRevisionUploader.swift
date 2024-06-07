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

final class PaginatedRevisionUploader: RevisionUploader {

    private let pageSize: Int
    private let parentProgress: Progress
    private let verifierFactory: (UploadingFileIdentifier) async throws -> UploadVerifier
    private let pageRevisionUploaderFactory: (RevisionPage) -> Operation
    private let signersKitFactory: SignersKitFactoryProtocol
    private let queue: OperationQueue
    private let moc: NSManagedObjectContext
    private var operationsContainer = OperationsContainer()

    private var isCancelled = false

    init(
        pageSize: Int,
        parentProgress: Progress,
        verifierFactory: @escaping (UploadingFileIdentifier) async throws -> UploadVerifier,
        pageRevisionUploaderFactory: @escaping (RevisionPage) -> Operation,
        signersKitFactory: SignersKitFactoryProtocol,
        queue: OperationQueue,
        moc: NSManagedObjectContext
    ) {
        self.pageSize = pageSize
        self.parentProgress = parentProgress
        self.verifierFactory = verifierFactory
        self.pageRevisionUploaderFactory = pageRevisionUploaderFactory
        self.signersKitFactory = signersKitFactory
        self.queue = queue
        self.moc = moc
    }

    func upload(_ draft: FileDraft, verification: BlockVerification, completion: @escaping Completion) {
        guard !isCancelled else { return }

        do {
            try draft.assertIsUploadingRevision(in: moc)

            // swiftlint:disable:next todo
            // TODO: Improve this in order not to have flow control statements all over the place
            guard !draft.isEmpty else {
                Log.info("STAGE: 3 Upload Revision 🏞📦☁️🏜️ finished ✅. UUID: \(draft.uploadID)", domain: .uploader)
                finalizeRevision(draft, completion: completion)
                return
            }

            let (pages, revision) = try revisionPages(for: draft, verification: verification)

            let pagesOperations = pages.map(makeOperation)
            let finalOperation = BlockOperation { [weak self] in
                guard let self, !self.isCancelled else { return }
                self.finalizeRevision(revision, completion: completion)
            }
            finalOperation.addDependencies(pagesOperations)
            let operations = pagesOperations + [finalOperation]
            operationsContainer.set(operations: operations)
            queue.addOperations(operations, waitUntilFinished: false)
        } catch {
            completion(.failure(error))
        }
    }

    func revisionPages(for draft: FileDraft, verification: BlockVerification) throws -> ([RevisionPage], Revision) {
        try moc.performAndWait {
            let revision = try draft.getUploadableRevision()
            let identifier = try revision.uploadableIdentifier()
            let addressID = try signersKitFactory.make(forSigner: .address(identifier.signatureEmail)).address.addressID

            let uploadBlocks = revision.blocks.compactMap(\.asUploadBlock).sorted { $0.index < $1.index }
            let nonUploadedBlocks = uploadBlocks.filter { !$0.isUploaded }

            let uploadThumbnails = Array(revision.thumbnails).sorted { $0.type < $1.type }
            let nonUploadedThumbnails = uploadThumbnails.filter { !$0.isUploaded }

            var blocksGroups = nonUploadedBlocks.splitInGroups(of: pageSize)

            Log.info("STAGE: 3 Will upload \(nonUploadedThumbnails.count) thumbnails 🏞, \(nonUploadedBlocks.count) blocks 📦 in \(blocksGroups.count) pages 📝 ☁️. UUID: \(draft.uploadID)", domain: .uploader)
            
            var pages: [RevisionPage] = []
            var group1: [UploadBlock] = []

            if !blocksGroups.isEmpty {
                group1 = blocksGroups.removeFirst()
            }

            let page1 = RevisionPage(index: 0, identifier: identifier, addressID: addressID, revision: revision, file: revision.file, blocks: group1, thumbnails: nonUploadedThumbnails, verification: verification)

            pages.append(page1)

            var i = 1
            for group in blocksGroups {
                pages.append(RevisionPage(index: i, identifier: identifier, addressID: addressID, revision: revision, file: revision.file, blocks: group, thumbnails: [], verification: verification))
                i += 1
            }

            updateProgress(uploadedBlocks: uploadBlocks.count - nonUploadedBlocks.count)
            updateProgress(uploadedBlocks: uploadThumbnails.count - nonUploadedThumbnails.count)
            return (pages, revision)
        }
    }

    func prepareVerification(_ draft: FileDraft) async throws -> BlockVerification {
        let uploadingFileIdentifier = try draft.getFileUploadingFileIdentifier()
        let verifier = try await verifierFactory(uploadingFileIdentifier)
        let verification = try await getVerificationCodes(verifier: verifier, fileDraft: draft, uploadingFileIdentifier: uploadingFileIdentifier)
        return verification
    }

    private func getVerificationCodes(verifier: UploadVerifier, fileDraft: FileDraft, uploadingFileIdentifier: UploadingFileIdentifier) async throws -> BlockVerification {
        let verifiableBlocks = try getVerifiableBlocks(fileDraft: fileDraft, uploadingFileIdentifier: uploadingFileIdentifier)
        let blocks = try await verifiableBlocks.asyncMap { block in
            let verificationToken = try await verifier.verify(block: block)
            return BlockVerification.Block(index: block.index, verificationToken: verificationToken)
        }
        return BlockVerification(blocks: blocks)
    }

    private func getVerifiableBlocks(fileDraft: FileDraft, uploadingFileIdentifier: UploadingFileIdentifier) throws -> [VerifiableBlock] {
        return try moc.performAndWait {
            let revision = try fileDraft.getUploadableRevision()
            let blocks = revision.blocks.compactMap(\.asUploadBlock)
            return blocks.map {
                VerifiableBlock(identifier: uploadingFileIdentifier, index: $0.index)
            }
        }
    }

    private func updateProgress(uploadedBlocks: Int) {
        parentProgress.complete(units: uploadedBlocks)
    }

    private func updateProgress(uploadedThumbnails: Int) {
        parentProgress.complete(units: uploadedThumbnails)
    }

    private func makeOperation(for page: RevisionPage) -> Operation {
        pageRevisionUploaderFactory(page)
    }

    private func finalizeRevision(_ draft: FileDraft, completion: @escaping Completion) {
        moc.perform { [weak self] in
            guard let self, !self.isCancelled else { return }
            
            guard let revision = draft.file.activeRevisionDraft else {
                let error = File.InvalidState(message: "Missing activeRevisionDraft")
                completion(.failure(error))
                return
            }
            self.finalizeRevision(revision, completion: completion)
        }
    }

    func finalizeRevision(_ revision: Revision, completion: @escaping Completion) {
        moc.perform { [weak self] in
            guard let self, !self.isCancelled else { return }

            do {
                revision.uploadState = .uploaded
                try self.moc.saveOrRollback()
                completion(.success)
            } catch {
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        operationsContainer.cancelAllOperations()
        isCancelled = true
    }

    deinit {
        operationsContainer.cancelAllOperations()
    }
}
