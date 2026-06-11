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

enum PageRevisionContentCreatorError: Error {
    case inconsistentRevisionPage
}

class PageRevisionContentCreator: ContentCreator {

    private let page: RevisionPage
    private let contentCreator: CloudContentCreator
    private let signersKitFactory: SignersKitFactoryProtocol
    private let moc: NSManagedObjectContext

    private var isCancelled = false

    init(
        page: RevisionPage,
        contentCreator: CloudContentCreator,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.page = page
        self.contentCreator = contentCreator
        self.signersKitFactory = signersKitFactory
        self.moc = moc
    }

    func create(completion: @escaping Completion) {
        guard !isCancelled else { return }

        do {
            let uploadableRevision = try getUploadableRevision(page)

            contentCreator.create(from: uploadableRevision) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success(let revision):
                    self.finalize(revision, completion)

                case .failure(let error as ResponseError) where CommitPolicy.quotaExceeded.contains(error.responseCode):
                    self.page.file.changeUploadingState(to: .cloudImpediment)
                    completion(.failure(FileUploaderError.insuficientSpace))

                case .failure(let error):
                    completion(.failure(error))
                }
            }

        } catch is EmptyPage {
            completion(.success)
        } catch {
            completion(.failure(error))
        }
    }

    func getUploadableRevision(_ page: RevisionPage) throws -> UploadableRevision {
        try moc.performAndWait {
            let revision = page.revision.in(moc: self.moc)
            let identifier = try revision.uploadableIdentifier()
#if os(macOS)
            let addressID = try revision.file.getContextShareAddressBasedSignersKit(
                signersKitFactory: signersKitFactory, fallbackSigner: .address(identifier.signatureEmail)
            ).address.addressID
#else
            let addressID = try revision.file.getContextShareAddressID()
#endif
            let blocks = try normalizedBlocks().compactMap {
                try makeUploadableBlock(block: $0, verification: page.verification)
            }
            let thumbnails = normalizedThumbnails().compactMap(\.uploadable)

            guard !blocks.isEmpty || !thumbnails.isEmpty else {
                throw EmptyPage()
            }

            return UploadableRevision(identifier: identifier, addressID: addressID, blocks: blocks, thumbnails: thumbnails)
        }
    }

    private func makeUploadableBlock(block: UploadBlock, verification: BlockVerification) throws -> UploadableBlock? {
        guard let verificationBlock = verification.blocks.first(where: { $0.index == block.index }) else {
            throw PageRevisionContentCreatorError.inconsistentRevisionPage
        }
        return UploadableBlock(block: block, verificationToken: verificationBlock.verificationToken)
    }

    private func finalize(_ fullUploadableRevision: FullUploadableRevision, _ completion: @escaping Completion) {
        moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { return }

            do {
                zip(fullUploadableRevision.blocks, normalizedBlocks()).forEach { fullUploadableBlock, block in
                    block.uploadToken = fullUploadableBlock.uploadToken
                    block.uploadUrl = fullUploadableBlock.remoteURL.absoluteString
                }
                
                zip(fullUploadableRevision.thumbnails, normalizedThumbnails()).forEach { fullUploadableThumbnail, thumbnail in
                    thumbnail.uploadURL = fullUploadableThumbnail.uploadURL.absoluteString
                }

                try moc.saveOrRollback()
                completion(.success)

            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func normalizedBlocks() -> [UploadBlock] {
        page.blocks.filter { $0.isUploaded == false }.sorted { $0.index < $1.index }
    }

    private func normalizedThumbnails() -> [Thumbnail] {
        page.thumbnails.filter { $0.isUploaded == false }.sorted { $0.type.rawValue < $1.type.rawValue }
    }

    func cancel() {
        isCancelled = true
    }

    struct EmptyPage: Error { }
}
