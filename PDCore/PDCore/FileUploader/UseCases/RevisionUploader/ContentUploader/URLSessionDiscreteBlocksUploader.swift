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

final class URLSessionDiscreteBlocksUploader: URLSessionDataTaskUploader, ContentUploader {
    private let uploadBlock: UploadBlock
    private let fullUploadableBlock: FullUploadableBlock
    private let uploadedBytesCounterResource: BytesCounterResource

    init(
        uploadBlock: UploadBlock,
        fullUploadableBlock: FullUploadableBlock,
        uploadID: UUID,
        progressTracker: Progress,
        session: URLSession,
        apiService: APIService,
        credentialProvider: CredentialProvider,
        moc: NSManagedObjectContext,
        uploadedBytesCounterResource: BytesCounterResource
    ) {
        self.uploadBlock = uploadBlock
        self.fullUploadableBlock = fullUploadableBlock
        self.uploadedBytesCounterResource = uploadedBytesCounterResource
        super.init(uploadID: uploadID, progressTracker: progressTracker, session: session, apiService: apiService, credentialProvider: credentialProvider, moc: moc)
    }

    func upload(completion: @escaping Completion) {
        guard !isCancelled else { return }

        guard let credential = credentialProvider.clientCredential() else {
            return completion(.failure(FileUploaderError.noCredentialFound))
        }

        do {
            guard FileManager.default.fileExists(atPath: fullUploadableBlock.localURL.path) else {
                throw ContentCleanedError(area: .block)
            }
            // Use mappedIfSafe to avoid heap allocation for such a short-lived thing.
            // Use uncached as we won't be using this file again later on the happy path.
            var data = try Data(contentsOf: fullUploadableBlock.localURL, options: [.mappedIfSafe, .uncached])
            let endpoint = UploadBlockFromDataEndpoint(url: fullUploadableBlock.remoteURL, data: &data, credential: credential, service: apiService)

            try setWillStartUpload()
            
            guard !isCancelled else { return }

            let originalSize: Int = moc.performAndWait { [weak self] in
                guard let self else { return 0 }
                return uploadBlock.clearSize
            }
            let uploadedBytesCount = data.count
            upload(data, originalSize: originalSize, request: endpoint.request) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                self.uploadedBytesCounterResource.add(bytes: uploadedBytesCount)
                self.handle(result, completion: completion)
            }

        } catch {
            completion(.failure(error))
        }
    }
    
    /// This will mark the blocks as invalid in case we want to resume the upload and we should request another URL
    private func setWillStartUpload() throws {
        try moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { return }
            
            guard uploadBlock.uploadUrl != nil && uploadBlock.uploadToken != nil else {
                throw uploadBlock.invalidState("The block should have an upload token.")
            }
            uploadBlock.unsetUploadableState()
            try moc.saveIfNeeded()
        }
    }
    
    override func saveUploadedState() {
        moc.performAndWait { [weak self] in
            // If we logout or the upload is cancelled, we should not save the state, we will retry again later
            guard let self, !self.isCancelled else { return }
            
            // We change the local state of the block to uploaded
            uploadBlock.isUploaded = true
            uploadBlock.uploadToken = fullUploadableBlock.uploadToken
            uploadBlock.uploadUrl = fullUploadableBlock.remoteURL.absoluteString
            
            do {
                // If we fail to save the local state, even if the block is uploaded, we will retry again later
                try moc.saveOrRollback()
            } catch {
                Log.error("Saving uploaded state failed", error: error, domain: .uploader)
            }
        }
    }
}
