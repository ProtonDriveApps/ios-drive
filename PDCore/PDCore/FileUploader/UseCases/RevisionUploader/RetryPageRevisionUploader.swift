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

class RetryPageRevisionUploader: PageRevisionUploader {
    let decoratee: PageRevisionUploader
    let maximumRetryCount: Int
    let uploadID: UUID
    let page: Int
    private var isCancelled = false

    init(decoratee: PageRevisionUploader, maximumRetryCount: Int, uploadID: UUID, page: Int) {
        self.decoratee = decoratee
        self.maximumRetryCount = maximumRetryCount
        self.uploadID = uploadID
        self.page = page
    }

    func upload(completion: @escaping (Result<Void, Error>) -> Void) {
        attemptUpload(attemptNumber: 0, completion: completion)
    }

    private func attemptUpload(attemptNumber: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isCancelled else { return }

        guard attemptNumber < maximumRetryCount else {
            completion(.failure(ResponseError(httpCode: nil, responseCode: RetryPolicy.iOSDriveRetriableCode, userFacingMessage: "Not all blocks or thumbnails were uploaded due to a retryable error", underlyingError: nil)))
            return
        }

        Log.info("STAGE: 3 Upload Page \(page) 🏞📦📝☁️ started. Attempt: \(attemptNumber). UUID: \(self.uploadID)", domain: .uploader)
        decoratee.upload { [weak self] result in
            guard let self = self, !self.isCancelled else { return }
            switch result {
            case .success:
                completion(.success)

            case .failure(let error):
                if error is PageFinishedWithRetriableErrors {
                    let delay = ExponentialBackoffWithJitter.getDelay(attempt: attemptNumber)
                    Log.info("STAGE: 3 Upload Page \(self.page) 🏞📦📝☁️ finished ⚠️ with errors. Will try again in \(delay) s. UUID: \(self.uploadID)", domain: .uploader)
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self, !self.isCancelled else { return }
                        self.attemptUpload(attemptNumber: attemptNumber + 1, completion: completion)
                    }
                } else {
                    Log.info("STAGE: 3 Upload Page \(self.page) 🏞📦📝☁️ failed ❌. UUID: \(self.uploadID)", domain: .uploader)
                    completion(.failure(error))
                }
            }
        }
    }

    func cancel() {
        isCancelled = true
        decoratee.cancel()
    }
}
