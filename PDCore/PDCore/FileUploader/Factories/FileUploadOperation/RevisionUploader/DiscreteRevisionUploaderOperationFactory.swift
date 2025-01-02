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

class DiscreteRevisionUploaderOperationFactory: FileUploadOperationFactory {

    let storage: StorageManager
    let client: PDClient.Client
    let api: APIService
    let cloudContentCreator: CloudContentCreator
    let credentialProvider: CredentialProvider
    let signersKitFactory: SignersKitFactoryProtocol
    let verifierFactory: UploadVerifierFactory
    let moc: NSManagedObjectContext
    let parallelEncryption: Bool
    let pagesQueue: OperationQueue
    let uploadQueue: OperationQueue
    private let blocksMeasurementRepository: FileUploadBlocksMeasurementRepositoryProtocol?
    let session = URLSession.forUploading()

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
        globalPagesQueue: OperationQueue? = nil,
        globalUploadQueue: OperationQueue? = nil,
        blocksMeasurementRepository: FileUploadBlocksMeasurementRepositoryProtocol? = nil
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
        pagesQueue = globalPagesQueue ?? OperationQueue(maxConcurrentOperation: Constants.discreteMaxConcurrentContentUploadOperations)
        pagesQueue.qualityOfService = .userInitiated
        uploadQueue = globalUploadQueue ?? OperationQueue(maxConcurrentOperation: Constants.maxConcurrentPageOperations)
        uploadQueue.qualityOfService = .userInitiated
        self.blocksMeasurementRepository = blocksMeasurementRepository
    }

    func make(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> any UploadOperation {
        let numberOfThumbnails = 1 // We aassume that the existence of a thumbnail will not affect the upload
        #if os(iOS)
        let parentProgress = Progress(unitsOfWork: draft.numberOfBlocks + numberOfThumbnails)
        #else
        let parentProgress = Progress(unitsOfWork: draft.file.size)
        parentProgress.kind = .file
        parentProgress.fileOperationKind = .uploading
        #endif

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
            pageRevisionUploaderFactory: { [weak self] page in
                guard let self else { return BlockOperation() }
                return self.makePageUploader(draft.uploadID, page, parentProgress, onError)
            },
            signersKitFactory: signersKitFactory,
            queue: uploadQueue,
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
            contentCreatorOperationFactory: { [weak self] in
                guard let self else { return BlockOperation() }
                return self.makeCreatorOperation(id, $0, onError)
            },
            blockUploaderOperationFactory: { [weak self] in
                guard let self else { return BlockOperation() }
                return self.makeBlockUploaderOperation(id, $0, $1, parentProgress, onError)
            },
            thumbnailUploaderOperationFactory: { [weak self] in
                guard let self else { return BlockOperation() }
                return self.makeThumbnailUploaderOperation(id, $0, $1, parentProgress, onError)
            },
            queue: pagesQueue,
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
        #if os(iOS)
        let blockProgress = parentProgress.child(pending: 1)
        #else
        let blockProgress = parentProgress
        #endif

        let uploader = URLSessionDiscreteBlocksUploader(
            uploadBlock: block,
            fullUploadableBlock: fullUploadableBlock,
            uploadID: id,
            progressTracker: blockProgress,
            session: session,
            apiService: api,
            credentialProvider: credentialProvider,
            moc: moc
        )

        return BlockUploaderOperation(
            id: id,
            index: fullUploadableBlock.uploadable.index,
            token: fullUploadableBlock.uploadToken,
            progressTracker: blockProgress,
            contentUploader: uploader,
            measurementRepository: blocksMeasurementRepository,
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
        #if os(iOS)
        let thumbnailProgress = parentProgress.child(pending: 1)
        #else
        let thumbnailProgress = Progress(unitsOfWork: 1)
        #endif

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
