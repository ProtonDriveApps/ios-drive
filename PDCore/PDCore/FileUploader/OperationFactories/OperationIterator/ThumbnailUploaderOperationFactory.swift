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

import PDClient

final class ThumbnailUploaderOperationFactory: OperationIterator {
    let draft: FileDraft
    let progress: Progress
    let api: APIService
    let credentialProvider: CredentialProvider
    let onError: OnError

    private var isFirstTime = true
    let estimatedUnitsOfWork: UnitOfWork = 4

    init(draft: FileDraft, progress: Progress, api: APIService, credentialProvider: CredentialProvider, onError: @escaping OnError) {
        self.draft = draft
        self.progress = progress
        self.api = api
        self.credentialProvider = credentialProvider
        self.onError = onError
        progress.modifyTotalUnitsOfWork(by: estimatedUnitsOfWork)
    }

    func next() -> Operation? {
        guard isFirstTime else { return nil }
        isFirstTime = false

        do {
            let thumbnail = try draft.getFullUploadableThumbnail()

            var operation: Operation
            if let thumbnail = thumbnail {
                let progress = Progress(unitsOfWork: 1)
                let uploader = URLSessionThumbnailUploader(thumbnail: thumbnail, progressTracker: progress, service: api, credentialProvider: credentialProvider)
                let urlSession = URLSession(configuration: .ephemeral, delegate: uploader, delegateQueue: nil)
                uploader.session = urlSession
                
                let op = ThumbnailUploaderOperation(draft: draft, progressTracker: progress, contentUploader: uploader)
                operation = op
                progress.addChild(progress, pending: estimatedUnitsOfWork)

            } else {
                let op = ImmediatelyFinishingOperation()
                operation = op
                progress.addChild(op.progress, pending: estimatedUnitsOfWork)
            }

            return operation

        } catch {
            onError(error)
            return NonFinishingOperation()
        }
    }
}
