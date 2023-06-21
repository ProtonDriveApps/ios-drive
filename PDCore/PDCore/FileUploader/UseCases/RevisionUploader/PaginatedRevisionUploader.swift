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
    private let pageRevisionUploaderFactory: (RevisionPage) -> Operation
    private let signersKitFactory: SignersKitFactoryProtocol
    private let queue: OperationQueue
    private let moc: NSManagedObjectContext

    private var isCancelled = false

    init(
        pageSize: Int,
        parentProgress: Progress,
        pageRevisionUploaderFactory: @escaping (RevisionPage) -> Operation,
        signersKitFactory: SignersKitFactoryProtocol,
        queue: OperationQueue,
        moc: NSManagedObjectContext
    ) {
        self.pageSize = pageSize
        self.parentProgress = parentProgress
        self.pageRevisionUploaderFactory = pageRevisionUploaderFactory
        self.signersKitFactory = signersKitFactory
        self.queue = queue
        self.moc = moc
    }

    func upload(_ draft: FileDraft, completion: @escaping Completion) {
        guard !isCancelled else { return }

        do {
            let (pages, revision) = try revisionPages(for: draft)

            for page in pages {
                let pageOperation = makeOperation(for: page)
                queue.addOperation(pageOperation)
            }

            queue.addBarrierBlock { [weak self] in
                self?.finalizeRevision(revision, completion: completion)
            }
        } catch {
            completion(.failure(error))
        }
    }

    func revisionPages(for draft: FileDraft) throws -> ([RevisionPage], Revision) {
        try moc.performAndWait {
            let revision = try draft.getUploadableRevision()
            let identifier = try revision.uploadableIdentifier()
            let addressID = try signersKitFactory.make(forSigner: .address(identifier.signatureEmail)).address.addressID

            let uploadBlocks = revision.blocks.compactMap(\.asUploadBlock)
            let nonUploadedBlocks = uploadBlocks.filter { !$0.isUploaded }

            let uploadThumbnails = Array(revision.thumbnails)
            let nonUploadedThumbnails = uploadThumbnails.filter { !$0.isUploaded }

            var blocksGroups = nonUploadedBlocks.splitInGroups(of: pageSize)

            var pages: [RevisionPage] = []
            let group1 = blocksGroups.removeLast()
            let page1 = RevisionPage(identifier: identifier, addressID: addressID, revision: revision, blocks: group1, thumbnails: nonUploadedThumbnails)

            pages.append(page1)

            for group in blocksGroups {
                pages.append(RevisionPage(identifier: identifier, addressID: addressID, revision: revision, blocks: group, thumbnails: []))
            }

            updateProgress(uploadedBlocks: uploadBlocks.count - nonUploadedBlocks.count)
            updateProgress(uploadedBlocks: uploadThumbnails.count - nonUploadedThumbnails.count)
            return (pages, revision)
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

    func finalizeRevision(_ revision: Revision, completion: Completion) {
        guard !isCancelled else { return }
        moc.performAndWait {
            do {
                revision.uploadState = .uploaded
                try moc.saveOrRollback()
                completion(.success)
            } catch {
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        isCancelled = true
        queue.cancelAllOperations()
    }
}
