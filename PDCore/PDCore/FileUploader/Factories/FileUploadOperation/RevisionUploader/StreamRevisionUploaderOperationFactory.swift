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
    let storage: StorageManager
    let client: PDClient.Client
    let api: APIService
    let cloudContentCreator: CloudContentCreator
    let credentialProvider: CredentialProvider
    let signersKitFactory: SignersKitFactoryProtocol
    let verifierFactory: UploadVerifierFactory
    let moc: NSManagedObjectContext
    let parallelEncryption: Bool
    let uploadedBytesCounterResource: BytesCounterResource

    init(
        storage: StorageManager,
        client: PDClient.Client,
        api: APIService,
        cloudContentCreator: CloudContentCreator,
        credentialProvider: CredentialProvider,
        signersKitFactory: SignersKitFactoryProtocol,
        verifierFactory: UploadVerifierFactory,
        moc: NSManagedObjectContext,
        parallelEncryption: Bool,
        uploadedBytesCounterResource: BytesCounterResource
    ) {
        self.storage = storage
        self.client = client
        self.api = api
        self.cloudContentCreator = cloudContentCreator
        self.credentialProvider = credentialProvider
        self.signersKitFactory = signersKitFactory
        self.verifierFactory = verifierFactory
        self.moc = moc
        self.parallelEncryption = parallelEncryption
        self.uploadedBytesCounterResource = uploadedBytesCounterResource
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
            verifierFactory: { [unowned self] identifier in
                try await self.makeVerifier(identifier: identifier)
            },
            pageRevisionUploaderFactory: { [unowned self] page in
                return self.makePageUploader(draft.uploadID, page, parentProgress, onError)
            },
            signersKitFactory: signersKitFactory,
            queue: OperationQueue(maxConcurrentOperation: Constants.maxConcurrentPageOperations),
            moc: moc,
            parallelEncryption: parallelEncryption
        )

        return PaginatedRevisionUploaderOperation(
            draft: draft,
            parentProgress: parentProgress,
            uploader: uploader,
            onError: { completion(.failure($0)) }
        )
    }
    
    private func makeVerifier(identifier: UploadingFileIdentifier) async throws -> UploadVerifier {
        try await verifierFactory.make(storage: storage, moc: moc, client: client, decryptionResource: Decryptor(), identifier: identifier)
    }

    func makePageUploader(_ id: UUID, _ page: RevisionPage, _ parentProgress: Progress, _ onError: @escaping OnUploadError) -> PageRevisionUploaderOperation {
        let uploader = ConcurrentPageRevisionUploader(
            page: page,
            contentCreatorOperationFactory: { [unowned self] in self.makeCreatorOperation(id, $0, onError) },
            blockUploaderOperationFactory: { [unowned self] in self.makeBlockUploaderOperation(id, $0, $1, parentProgress, onError) },
            thumbnailUploaderOperationFactory: { [unowned self] in self.makeThumbnailUploaderOperation(id, $0, $1, parentProgress, onError) },
            queue: .serial,
            moc: moc
        )
        let retryRevisionUploader = RetryPageRevisionUploader(decoratee: uploader, maximumRetryCount: 3, uploadID: id, page: page.index)
        return PageRevisionUploaderOperation(uploader: retryRevisionUploader, onError: onError)
    }

    func makeCreatorOperation(_ id: UUID, _ page: RevisionPage, _ onError: @escaping OnUploadError) -> Operation {
        let contentCreator = PageRevisionContentCreator(
            page: page,
            contentCreator: cloudContentCreator,
            signersKitFactory: signersKitFactory,
            moc: moc
        )
        return ContentsCreatorOperation(id: id, contentCreator: contentCreator, onError: onError)
    }

    func makeBlockUploaderOperation(
        _ id: UUID,
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
            credentialProvider: credentialProvider,
            uploadedBytesCounterResource: uploadedBytesCounterResource
        )
        let session = URLSession.forUploading(delegate: uploader)
        uploader.session = session

        return BlockUploaderOperation(
            id: id,
            index: fullUploadableBlock.uploadable.index,
            token: fullUploadableBlock.uploadToken,
            progressTracker: blockProgress,
            contentUploader: uploader,
            measurementRepository: nil, // Right now we don't have any need for tracking stream upload of blocks
            onError: onError
        )
    }

    func makeThumbnailUploaderOperation(
        _ id: UUID,
        _ thumbnail: Thumbnail,
        _ fullUploadableThumbnail: FullUploadableThumbnail,
        _ parentProgress: Progress,
        _ onError: @escaping OnUploadError
    ) -> Operation {
        let thumbnailProgress = parentProgress.child(pending: 1)
        
        let session = URLSession.forUploading()

        let uploader = URLSessionThumbnailUploader(
            thumbnail: thumbnail,
            fullUploadableThumbnail: fullUploadableThumbnail,
            uploadID: id,
            progressTracker: thumbnailProgress,
            session: session,
            apiService: api,
            credentialProvider: credentialProvider,
            moc: moc
        )

        return ThumbnailUploaderOperation(
            id: id,
            index: fullUploadableThumbnail.uploadable.type,
            token: fullUploadableThumbnail.uploadToken,
            progress: thumbnailProgress,
            contentUploader: uploader,
            onError: onError
        )
    }
}
