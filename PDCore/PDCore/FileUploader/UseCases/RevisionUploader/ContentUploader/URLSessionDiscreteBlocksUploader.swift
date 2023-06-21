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

final class URLSessionDiscreteBlocksUploader: URLSessionDataTaskUploader, ContentUploader {
    private let uploadBlock: UploadBlock
    private let fullUploadableBlock: FullUploadableBlock

    init(
        uploadBlock: UploadBlock,
        fullUploadableBlock: FullUploadableBlock,
        progressTracker: Progress,
        session: URLSession,
        apiService: APIService,
        credentialProvider: CredentialProvider
    ) {
        self.uploadBlock = uploadBlock
        self.fullUploadableBlock = fullUploadableBlock
        super.init(progressTracker: progressTracker, session: session, apiService: apiService, credentialProvider: credentialProvider)
    }

    func upload(completion: @escaping Completion) {
        guard !isCancelled else { return }

        guard let credential = credentialProvider.clientCredential() else {
            return completion(.failure(UploaderErrors.noCredentialInCloudSlot))
        }

        do {
            var data = try Data(contentsOf: fullUploadableBlock.localURL)
            let endpoint = UploadBlockFromDataEndpoint(url: fullUploadableBlock.remoteURL, data: &data, credential: credential, service: apiService)
            try setWillStartUpload()

            upload(data, request: endpoint.request) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                self.handle(result, completion: completion)
            }

        } catch {
            completion(.failure(error))
        }
    }

    override func saveUploadedState() {
        guard let moc = uploadBlock.moc else { return }

        moc.performAndWait {
            uploadBlock.isUploaded = true
            uploadBlock.uploadToken = fullUploadableBlock.uploadToken
            uploadBlock.uploadUrl = fullUploadableBlock.remoteURL.absoluteString
            try? moc.save()
        }
    }

    /// This will mark the blocks as invalid in case we want to resume the upload and we should request another URL
    private func setWillStartUpload() throws {
        guard let moc = uploadBlock.moc else {
            throw Block.noMOC()
        }

        try moc.performAndWait {
            uploadBlock.unsetUploadableState()
            try moc.saveIfNeeded()
        }
    }
}
