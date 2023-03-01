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

final class URLSessionDiscreteBlocksUploader: URLSessionContentUploader {

    private let block: FullUploadableBlock
    private let service: Service
    private let credentialProvider: CredentialProvider

    init(
        block: FullUploadableBlock,
        progressTracker: Progress,
        service: Service,
        credentialProvider: CredentialProvider
    ) {
        self.block = block
        self.service = service
        self.credentialProvider = credentialProvider
        super.init(progressTracker: progressTracker)
    }

    override func upload() {
        upload(attempt: 0)
    }

    func upload(attempt: Int) {
        guard attempt < 3 else {
            self.onCompletion(.failure(ConnectionLostError()))
            return
        }

        guard let credential = credentialProvider.clientCredential() else {
            return onCompletion(.failure(Uploader.Errors.noCredentialInCloudSlot))
        }

        do {
            var data = try Data(contentsOf: block.localURL)
            let endpoint = UploadBlockFromDataEndpoint(url: block.remoteURL, data: &data, credential: credential, service: service)

            guard session != nil else { return }

            let task = session.uploadTask(
                with: endpoint.request,
                from: data,
                completionHandler: { [weak self] data, response, error in
                    guard let self = self, !self.isCancelled else { return }

                    if let nsError = error as? NSError,
                       nsError.code == self.networkConnectionLostErrorCode {
                        return self.upload(attempt: attempt + 1)
                    } else if let error = error {
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

        } catch {
            onCompletion(.failure(error))
        }
    }

    var networkConnectionLostErrorCode: Int { -1005 }

    struct ConnectionLostError: Error {}
}
