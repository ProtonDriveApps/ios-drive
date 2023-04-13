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
        try moc.performAndWait{
            let revision = page.revision.in(moc: self.moc)
            let identifier = try revision.uploadableIdentifier()
            let addressID = try signersKitFactory.make(forSigner: .address(identifier.signatureEmail)).address.addressID
            let blocks = normalizedBlocks().compactMap(UploadableBlock.init)
            let thumbnail = normalizedThumbnail()?.uploadable

            guard !blocks.isEmpty || thumbnail != nil else {
                throw EmptyPage()
            }

            return UploadableRevision(identifier: identifier, addressID: addressID, blocks: blocks, thumbnail: thumbnail)
        }
    }

    private func finalize(_ fullUploadableRevision: FullUploadableRevision, _ completion: @escaping Completion) {
        moc.performAndWait {
            do {
                zip(fullUploadableRevision.blocks, normalizedBlocks()).forEach { fullUploadableBlock, block in
                    block.uploadToken = fullUploadableBlock.uploadToken
                    block.uploadUrl = fullUploadableBlock.remoteURL.absoluteString
                }
                normalizedThumbnail()?.uploadURL = fullUploadableRevision.thumbnail?.uploadURL.absoluteString

                try moc.saveOrRollback()
                completion(.success)

            } catch {
                completion(.failure(error))
            }
        }
    }

    private func normalizedBlocks() -> [UploadBlock] {
        page.blocks.filter { $0.isUploaded == false }
    }

    private func normalizedThumbnail() -> Thumbnail? {
        [page.thumbnail].compactMap { $0 }.filter { $0.isUploaded == false }.first
    }

    func cancel() {
        isCancelled = true
    }

    struct EmptyPage: Error { }
}
