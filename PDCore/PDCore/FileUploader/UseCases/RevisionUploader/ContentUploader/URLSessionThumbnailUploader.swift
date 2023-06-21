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

final class URLSessionThumbnailUploader: URLSessionDataTaskUploader, ContentUploader {

    private let thumbnail: Thumbnail
    private let fullUploadableThumbnail: FullUploadableThumbnail

    init(
        thumbnail: Thumbnail,
        fullUploadableThumbnail: FullUploadableThumbnail,
        progressTracker: Progress,
        session: URLSession,
        apiService: APIService,
        credentialProvider: CredentialProvider
    ) {
        self.thumbnail = thumbnail
        self.fullUploadableThumbnail = fullUploadableThumbnail
        super.init(progressTracker: progressTracker, session: session, apiService: apiService, credentialProvider: credentialProvider)
    }

    func upload(completion: @escaping Completion) {
        guard !isCancelled else { return }

        guard let credential = credentialProvider.clientCredential() else {
            return completion(.failure(UploaderErrors.noCredentialInCloudSlot))
        }

        do {
            var data = fullUploadableThumbnail.uploadable.encrypted
            let endpoint = UploadBlockFromDataEndpoint(url: fullUploadableThumbnail.uploadURL, data: &data, credential: credential, service: apiService)

            try setWillStartUpload()

            upload(data, request: endpoint.request) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                self.handle(result, completion: completion)
            }

        } catch {
            completion(.failure(error))
        }
    }

    /// This will mark the thumbnail as invalid in case we want to resume the upload and we should request another URL
    private func setWillStartUpload() throws {
        guard let moc = thumbnail.moc else { throw Thumbnail.noMOC() }

        try moc.performAndWait {
            thumbnail.unsetUploadableState()
            try moc.saveOrRollback()
        }
    }

    override func saveUploadedState() {
        guard let moc = thumbnail.moc else { return }

        moc.performAndWait {
            thumbnail.isUploaded = true
            thumbnail.uploadURL = fullUploadableThumbnail.uploadURL.absoluteString
            try? moc.save()
        }
    }

    private func finalizeWithNoSpaceOnCloudError() {
        guard let moc = thumbnail.moc else { return }

        moc.performAndWait {
            thumbnail.revision.file.state = .cloudImpediment
            try? moc.saveOrRollback()
        }
    }
}
