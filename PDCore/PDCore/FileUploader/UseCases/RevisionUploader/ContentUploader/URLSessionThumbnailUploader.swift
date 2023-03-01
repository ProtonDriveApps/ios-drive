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

final class URLSessionThumbnailUploader: URLSessionContentUploader {

    private let thumbnail: FullUploadableThumbnail
    private let service: Service
    private let credentialProvider: CredentialProvider

    init(
        thumbnail: FullUploadableThumbnail,
        progressTracker: Progress,
        service: Service,
        credentialProvider: CredentialProvider
    ) {
        self.thumbnail = thumbnail
        self.service = service
        self.credentialProvider = credentialProvider
        super.init(progressTracker: progressTracker)
    }

    override func upload() {
        guard let credential = credentialProvider.clientCredential() else {
            return onCompletion(.failure(Uploader.Errors.noCredentialInCloudSlot))
        }

        var data = thumbnail.uploadable.encrypted
        let endpoint = UploadBlockFromDataEndpoint(url: thumbnail.uploadURL, data: &data, credential: credential, service: service)

        let task = session.uploadTask(
            with: endpoint.request,
            from: data,
            completionHandler: { [weak self] data, response, error in
                guard let self = self, !self.isCancelled else { return }

                if let error = error {
                    return self.onCompletion(.failure(error))
                }

                if let data = data {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .decapitaliseFirstLetter

                    if let error = try? decoder.decode(PDClient.ErrorResponse.self, from: data) {
                        self.onCompletion(.failure(error))

                    } else {
                        self.cleanSession()
                        self.onCompletion(.success)
                    }

                } else {
                    self.onCompletion(.failure(InvalidRepresentationError()))
                }

            }
        )
        progressTracker.addChild(task.progress, withPendingUnitCount: 1)

        self.task = task

        task.resume()
    }
}
