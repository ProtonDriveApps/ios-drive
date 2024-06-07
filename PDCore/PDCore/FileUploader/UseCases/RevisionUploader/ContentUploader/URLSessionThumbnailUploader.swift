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
import CoreData

final class URLSessionThumbnailUploader: URLSessionDataTaskUploader, ContentUploader {

    private let thumbnail: Thumbnail
    private let fullUploadableThumbnail: FullUploadableThumbnail

    init(
        thumbnail: Thumbnail,
        fullUploadableThumbnail: FullUploadableThumbnail,
        uploadID: UUID,
        progressTracker: Progress,
        session: URLSession,
        apiService: APIService,
        credentialProvider: CredentialProvider,
        moc: NSManagedObjectContext
    ) {
        self.thumbnail = thumbnail
        self.fullUploadableThumbnail = fullUploadableThumbnail
        super.init(uploadID: uploadID, progressTracker: progressTracker, session: session, apiService: apiService, credentialProvider: credentialProvider, moc: moc)
    }

    func upload(completion: @escaping Completion) {
        guard !isCancelled else { return }

        guard let credential = credentialProvider.clientCredential() else {
            return completion(.failure(FileUploaderError.noCredentialFound))
        }

        do {
            var data = fullUploadableThumbnail.uploadable.encrypted
            let endpoint = UploadBlockFromDataEndpoint(url: fullUploadableThumbnail.uploadURL, data: &data, credential: credential, service: apiService)

            try setWillStartUpload()
            
            guard !isCancelled else { return }

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
        try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { return }

            guard thumbnail.uploadURL != nil else {
                throw thumbnail.invalidState("The thumbnail should have an upload token.")
            }
            thumbnail.unsetUploadableState()
            try moc.saveOrRollback()
        }
    }

    override func saveUploadedState() {
        moc.performAndWait { [weak self] in
            // If we logout or the upload is cancelled, we should not save the state, we will retry again later
            guard let self, !self.isCancelled else { return }
            
            // We change the local state of the thumbnail to uploaded
            thumbnail.isUploaded = true
            thumbnail.uploadURL = fullUploadableThumbnail.uploadURL.absoluteString
            do {
                // If we fail to save the local state, even if the thumbnail is uploaded, we will retry again later
                #if os(iOS)
                try moc.saveOrRollback()
                #else
                try moc.saveWithParentLinkCheck()
                #endif
                moc.refresh(thumbnail, mergeChanges: false)
            } catch {
                Log.error(error, domain: .uploader)
            }
        }
    }
}
