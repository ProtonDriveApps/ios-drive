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
import PDClient

protocol RevisionUploaderOperationFactory {
    func make(draft: FileDraft, onError: @escaping OnError) -> OperationWithProgress
}

final class DiscreteRevisionUploaderOperationFactory: RevisionUploaderOperationFactory {
    let api: APIService
    let contentCreator: CloudContentCreator
    let credentialProvider: CredentialProvider

    init(api: APIService, contentCreator: CloudContentCreator, credentialProvider: CredentialProvider) {
        self.api = api
        self.contentCreator = contentCreator
        self.credentialProvider = credentialProvider
    }

    func make(draft: FileDraft, onError: @escaping OnError) -> OperationWithProgress {
        let progress = Progress(unitsOfWork: 0)

        let onError: OnError = { error in
            progress.cancel()
            onError(error)
        }

        let contentCreatorFactory = ContentCreatorOperationFactory(draft: draft, progress: progress, contentCreator: contentCreator, onError: onError)
        let blocksUploaderFactory = BlockUploaderOperationFactory(
            draft: draft,
            progress: progress,
            uploader: { [unowned api, unowned credentialProvider] (block, tracker) in
                URLSessionDiscreteBlocksUploader(block: block, progressTracker: tracker, service: api, credentialProvider: credentialProvider)
            },
            onError: onError
        )
        let thumbnailUploaderFactory = ThumbnailUploaderOperationFactory(draft: draft, progress: progress, api: api, credentialProvider: credentialProvider, onError: onError)
        let blocksAndthumbnailsUploaderFactory = SequentialOperationIterator(
            startIterator: blocksUploaderFactory,
            endIterator: thumbnailUploaderFactory
        )

        let uploaderProcessor = RevisionOperationsProcessor(
            serial: contentCreatorFactory,
            concurrent: blocksAndthumbnailsUploaderFactory,
            maxConcurrentOperations: 5
        )

        return RevisionUploaderOperation(
            draft: draft,
            progress: progress,
            uploader: uploaderProcessor,
            onError: onError
        )
    }

}

final class StreamRevisionUploaderOperationFactory: RevisionUploaderOperationFactory {

    private let api: APIService
    private let contentCreator: CloudContentCreator
    private let credentialProvider: CredentialProvider

    init(api: APIService, contentCreator: CloudContentCreator, credentialProvider: CredentialProvider) {
        self.api = api
        self.contentCreator = contentCreator
        self.credentialProvider = credentialProvider
    }

    func make(draft: FileDraft, onError: @escaping OnError) -> OperationWithProgress {
        let progress = Progress(unitsOfWork: 0)

        let onError: OnError = { error in
            progress.cancel()
            onError(error)
        }

        let contentCreatorFactory = ContentCreatorOperationFactory(draft: draft, progress: progress, contentCreator: contentCreator, onError: onError)
        let blocksUploaderFactory = BlockUploaderOperationFactory(
            draft: draft,
            progress: progress,
            uploader: { [unowned api, unowned credentialProvider] (block, tracker) in
                URLSessionStreamBlockUploader(block: block, progressTracker: tracker, service: api, credentialProvider: credentialProvider)
            },
            onError: onError
        )
        let thumbnailUploaderFactory = ThumbnailUploaderOperationFactory(draft: draft, progress: progress, api: api, credentialProvider: credentialProvider, onError: onError)
        let blocksAndthumbnailsUploaderFactory = SequentialOperationIterator(
            startIterator: blocksUploaderFactory,
            endIterator: thumbnailUploaderFactory
        )

        let uploaderProcessor = RevisionOperationsProcessor(
            serial: contentCreatorFactory,
            concurrent: blocksAndthumbnailsUploaderFactory,
            maxConcurrentOperations: 1
        )

        return RevisionUploaderOperation(
            draft: draft,
            progress: progress,
            uploader: uploaderProcessor,
            onError: onError
        )
    }

}
