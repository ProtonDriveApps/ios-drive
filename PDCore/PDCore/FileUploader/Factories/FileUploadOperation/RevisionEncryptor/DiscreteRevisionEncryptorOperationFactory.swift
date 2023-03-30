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

class DiscreteRevisionEncryptorOperationFactory: FileUploadOperationFactory {

    let signersKitFactory: SignersKitFactoryProtocol
    let moc: NSManagedObjectContext

    init(
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.signersKitFactory = signersKitFactory
        self.moc = moc
    }

    func make(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> OperationWithProgress {
        let progress = Progress(unitsOfWork: draft.numberOfBlocks + 2)

        let revisionEncryptor = makeRevisionEncryptor(progress, blocks: draft.numberOfBlocks)
        return RevisionEncryptionOperation(progress: progress, draft: draft, revisionEncryptor: revisionEncryptor, onError: { completion(.failure($0)) })
    }

    func makeRevisionEncryptor(_ progress: Progress, blocks: Int) -> RevisionEncryptor {
        let blocksEncryptor = makeBlocksRevisionEncryptor(progress: progress.child(pending: blocks), moc: moc.childContext())
        let thumbnailEncryptor = makeThumbnailRevisionEncryptor(progress: progress.child(pending: 1), moc: moc.childContext())
        let xAttrEncryptor = makeExtendedAttributesRevisionEncryptor(progress: progress.child(pending: 1), moc: moc.childContext())

        return DefaultRevisionEncryptor(
            blocksEncryptor: blocksEncryptor,
            thumbnailEncryptor: thumbnailEncryptor,
            xAttributesEncryptor: xAttrEncryptor,
            moc: moc
        )
    }

    func makeBlocksRevisionEncryptor(progress: Progress, moc: NSManagedObjectContext) -> RevisionEncryptor {
        DiscreteBlocksRevisionEncryptor(signersKitFactory: signersKitFactory, maxBlockSize: maxBlockSize(), progress: progress, moc: moc)
    }

    func makeThumbnailRevisionEncryptor(progress: Progress, moc: NSManagedObjectContext) -> RevisionEncryptor {
        ThumbnailRevisionEncryptor(thumbnailProvider: makeThumbnailProvider(), signersKitFactory: signersKitFactory, progress: progress, moc: moc)
    }

    func makeExtendedAttributesRevisionEncryptor(progress: Progress, moc: NSManagedObjectContext) -> ExtendedAttributesRevisionEncryptor {
        ExtendedAttributesRevisionEncryptor(signersKitFactory: signersKitFactory, maxBlockSize: maxBlockSize(), progress: progress, moc: moc)
    }

    func makeThumbnailProvider() -> ThumbnailProvider {
        let provider = CGImageThumbnailProvider()
        provider
            .setNext(PDFThumbnailProvider())
            .setNext(VideoThumbnailProvider())

        return provider
    }

    func maxBlockSize() -> Int {
        Constants.maxBlockSize
    }
}
