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
import ProtonCoreNetworking
import CoreData

extension JSONSerialization {
    static func json(data: Data?) -> [String: Any]? {
        guard let data = data else { return nil }
        return try? jsonObject(with: data, options: []) as? [String: Any]
    }
}

class URLSessionDataTaskUploader {

    let apiService: APIService
    let credentialProvider: CredentialProvider
    let moc: NSManagedObjectContext

    var isCancelled = false
    weak var task: URLSessionUploadTask?

    private let progressTracker: Progress
    private let session: URLSession
    let uploadID: UUID

    init(
        uploadID: UUID,
        progressTracker: Progress,
        session: URLSession,
        apiService: APIService,
        credentialProvider: CredentialProvider,
        moc: NSManagedObjectContext
    ) {
        self.uploadID = uploadID
        self.progressTracker = progressTracker
        self.session = session
        self.apiService = apiService
        self.credentialProvider = credentialProvider
        self.moc = moc
    }

    func upload(_ data: Data, request: URLRequest, completion: @escaping (Result<Void, ResponseError>) -> Void) {
        // this `URLSessionUploadTask` retains the `data` even after the request is completed, unit task is released
        let id = self.uploadID
        let uploadTask = session.uploadTask(with: request, from: data) { [weak self] data, response, error in
            guard let self, !self.isCancelled else { return }
            
            completion(Self.parse(response, responseDict: JSONSerialization.json(data: data), error: error as? NSError, id: id))
        }
        progressTracker.addChild(uploadTask.progress, withPendingUnitCount: 1)

        task = uploadTask
        task?.resume()
    }
    
    static func parse(_ urlResponse: URLResponse?, responseDict: [String: Any]?, error: NSError?, id: UUID) -> Result<Void, ResponseError> {
        if let error {
            Log.info("STAGE: 3.2 📦🏞️❌ error: \(error.localizedDescription). UUID: \(id)", domain: .uploader)
            return .failure(ResponseError(httpCode: nil, responseCode: nil, userFacingMessage: nil, underlyingError: error))
        }

        guard let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode else {
            Log.info("STAGE: 3.2 📦🏞️❌ url response is not http response. UUID: \(id)", domain: .uploader)
            return .failure(ResponseError(httpCode: nil, responseCode: nil, userFacingMessage: nil, underlyingError: error ?? (URLSessionInvalidRepresentationError() as NSError)))
        }
        
        if let code = responseDict?.code, code == 1000 || code == 1001 {
            return .success
        } else {
            let protonCode = responseDict?.code.map { " \($0)" } ?? ""
            let message = "Netwok error\(protonCode). \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))"
            Log.info("STAGE: 3.2 📦🏞️❌ \(message) UUID: \(id)", domain: .uploader)
            return .failure(
                ResponseError(
                    httpCode: statusCode,
                    responseCode: responseDict?.code,
                    userFacingMessage: responseDict?.error ?? HTTPURLResponse.localizedString(forStatusCode: statusCode),
                    underlyingError: error
                )
            )
        }
    }

    func handle(_ result: Result<Void, ResponseError>, completion: @escaping ContentUploader.Completion) {
        switch result {
        case .success:
            self.saveUploadedState()
            completion(.success)
        case .failure(let error):
            completion(.failure(error))
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
