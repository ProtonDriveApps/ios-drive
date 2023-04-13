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

class URLSessionDataTaskUploader {

    let apiService: APIService
    let credentialProvider: CredentialProvider

    var isCancelled = false
    var task: URLSessionUploadTask?

    private let progressTracker: Progress
    private let session: URLSession

    init(
        progressTracker: Progress,
        session: URLSession,
        apiService: APIService,
        credentialProvider: CredentialProvider
    ) {
        self.progressTracker = progressTracker
        self.session = session
        self.apiService = apiService
        self.credentialProvider = credentialProvider
    }

    func upload(_ data: Data, request: URLRequest, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        let uploadTask = session.uploadTask(with: request, from: data) { data, response, error in
            completion(Result {
                if let error = error {
                    throw error
                }

                if let data = data, let response = response as? HTTPURLResponse {
                    return (data, response)
                } else {
                    throw URLSessionInvalidRepresentationError()
                }
            })
        }
        progressTracker.addChild(uploadTask.progress, withPendingUnitCount: 1)

        task = uploadTask
        task?.resume()
    }

    func handle(_ result: Result<(Data, HTTPURLResponse),Error>, completion: @escaping (Result<Void, Error>) -> Void) {
        switch result {
        case .success((let data, let httpResponse)):
            do {
                let decoder = JSONDecoder(strategy: .decapitaliseFirstLetter)
                let response = try decoder.decode(ContentUploadResponse.self, from: data)

                if httpResponse.statusCode == 200 && response.isSuccess {
                    self.saveUploadedState()
                    completion(.success)
                } else {
                    let responseError = ResponseError(httpCode: httpResponse.statusCode, responseCode: response.code, userFacingMessage: response.error ?? response .errorDescription, underlyingError: nil)
                    if responseError.httpCode == 422, response.code == 2501 {
                        completion(.failure(FileUploaderError.expiredUploadURL))
                    } else {
                        completion(.failure(responseError))
                    }
                }

            } catch {
                completion(.failure(
                    ResponseError(httpCode: httpResponse.statusCode, responseCode: nil, userFacingMessage: nil, underlyingError: error as NSError)
                ))
            }
        case .failure(let error as NSError) where RetryPolicy.retryableErrorCodes.contains(error.code):
            completion(.failure(UploadNonCompleted()))
        case .failure(let error):
            completion(.failure(
                ResponseError(httpCode: nil, responseCode: nil, userFacingMessage: nil, underlyingError: error as NSError)
            ))
        }
    }

    func saveUploadedState() { fatalError("Please override.") }

    func cancel() {
        isCancelled = true
        task?.cancel()
        task = nil
    }

    public struct UploadResponse: Codable {
        public let code: Int
    }
}

struct ContentUploadResponse: Codable {
    let code: Int
    let error: String?
    let errorDescription: String?

    var isSuccess: Bool {
        code == 1000
    }
}
