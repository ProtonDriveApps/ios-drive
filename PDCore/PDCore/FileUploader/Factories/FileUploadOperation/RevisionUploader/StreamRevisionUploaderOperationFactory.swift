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
import PDClient

class StreamRevisionUploaderOperationFactory: FileUploadOperationFactory {
    let api: APIService
    let cloudContentCreator: CloudContentCreator
    let credentialProvider: CredentialProvider
    let signersKitFactory: SignersKitFactoryProtocol
    let moc: NSManagedObjectContext

    init(
        api: APIService,
        cloudContentCreator: CloudContentCreator,
        credentialProvider: CredentialProvider,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.api = api
        self.cloudContentCreator = cloudContentCreator
        self.credentialProvider = credentialProvider
        self.signersKitFactory = signersKitFactory
        self.moc = moc
    }

    func make(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> any UploadOperation {
        let parentProgress = Progress(unitsOfWork: draft.numberOfBlocks)

        let onError: OnUploadError = { error in
            parentProgress.cancel()
            completion(.failure(error))
        }

        let uploader = PaginatedRevisionUploader(
            pageSize: Constants.blocksPaginationPageSize,
            parentProgress: parentProgress,
            pageRevisionUploaderFactory: { [unowned self] page in
                return self.makePageUploader(page, parentProgress, onError)
            },
            signersKitFactory: signersKitFactory,
            queue: OperationQueue(maxConcurrentOperation: Constants.maxConcurrentPageOperations),
            moc: moc
        )

        return PaginatedRevisionUploaderOperation(
            draft: draft,
            parentProgress: parentProgress,
            uploader: uploader,
            onError: { completion(.failure($0)) }
        )
    }

    func makePageUploader(_ page: RevisionPage, _ parentProgress: Progress, _ onError: @escaping OnUploadError) -> PageRevisionUploaderOperation {
        let uploader = ConcurrentPageRevisionUploader(
            page: page,
            contentCreatorOperationFactory: { [unowned self] in self.makeCreatorOperation($0, onError) },
            blockUploaderOperationFactory: { [unowned self] in self.makeBlockUploaderOperation($0, $1, parentProgress, onError) },
            thumbnailUploaderOperationFactory: { [unowned self] in self.makeThumbnailUploaderOperation($0, $1, parentProgress) },
            queue: .serial,
            moc: moc
        )
        return PageRevisionUploaderOperation(uploader: uploader, onError: onError)
    }

    func makeCreatorOperation(_ page: RevisionPage, _ onError: @escaping OnUploadError) -> Operation {
        let contentCreator = PageRevisionContentCreator(
            page: page,
            contentCreator: cloudContentCreator,
            signersKitFactory: signersKitFactory,
            moc: moc
        )
        return ContentsCreatorOperation(contentCreator: contentCreator, onError: onError)
    }

    func makeBlockUploaderOperation(
        _ block: UploadBlock,
        _ fullUploadableBlock: FullUploadableBlock,
        _ parentProgress: Progress,
        _ onError: @escaping OnUploadError
    ) -> Operation {
        let blockProgress = parentProgress.child(pending: 1)

        let uploader = URLSessionStreamBlockUploader(
            uploadBlock: block,
            fullUploadableBlock: fullUploadableBlock,
            progressTracker: blockProgress,
            service: api,
            credentialProvider: credentialProvider
        )
        let session = URLSession(configuration: .ephemeral, delegate: uploader, delegateQueue: nil)
        uploader.session = session

        return BlockUploaderOperation(
            progressTracker: blockProgress,
            blockIndex: fullUploadableBlock.uploadable.index,
            contentUploader: uploader,
            onError: onError
        )
    }

    func makeThumbnailUploaderOperation(
        _ thumbnail: Thumbnail,
        _ fullUploadableThumbnail: FullUploadableThumbnail,
        _ parentProgress: Progress
    ) -> Operation {
        let thumbnailProgress = parentProgress.child(pending: 1)

        let uploader = URLSessionThumbnailUploader(
            thumbnail: thumbnail,
            fullUploadableThumbnail: fullUploadableThumbnail,
            progressTracker: thumbnailProgress,
            session: URLSession(configuration: .ephemeral),
            apiService: api,
            credentialProvider: credentialProvider
        )

        return ThumbnailUploaderOperation(
            progressTracker: thumbnailProgress,
            contentUploader: uploader
        )
    }
}
