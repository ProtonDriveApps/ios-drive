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

class DownloadBlockOperation: DownloadBinaryOperation {
    typealias Completion = (Result<URL, Error>) -> Void

    let completion: Completion
    private let endpointFactory: EndpointFactory
    private(set) var progress: Progress!
    private var timeoutHandler: (() -> Void)?
    
    init(
        downloadTaskURL: URL,
        endpointFactory: EndpointFactory,
        completionHandler: @escaping Completion
    ) {
        self.endpointFactory = endpointFactory
        self.completion = completionHandler
        self.progress = Progress(totalUnitCount: 1)
        super.init(url: downloadTaskURL)

        self.completionBlock = { [weak self] in
            guard let self else { return }
            self.progress?.completedUnitCount = 1
            self.task = nil
            if !Constants.downloaderUsesSharedURLSession {
                self.session?.invalidateAndCancel()
            }
            self.session = nil
        }
    }
    
    override func start() {
        super.start()
        guard !self.isCancelled else { return }

        guard let request = makeRequest() else {
            cancel()
            return
        }

        let okStatusCode = 200

        task = session?.downloadTask(with: request, completionHandler: { [weak self] localURL, response, error in
            guard let self = self, !self.isCancelled else {
                return
            }
            
            if let error = error {
                self.completion(.failure(error))
                self.state = .finished
                return
            }

            if let response = response as? HTTPURLResponse,
               response.statusCode != okStatusCode {
                self.completion(.failure(BlockDownloadError(code: response.statusCode)))
                self.state = .finished
                return
            }
            
            self.completion(.success(localURL!))
            self.state = .finished
        })
        
        if let subprogress = self.task?.progress {
            self.progress?.addChild(subprogress, withPendingUnitCount: 1)
        }
        
        self.task?.resume()
    }

    private func makeRequest() -> URLRequest? {
        guard let url = url else {
            return nil
        }
        return try? endpointFactory.makeDownloadBlockEndpoint(url: url).request
    }
    
    override func cancel() {
        super.cancel()
        self.progress?.cancel()

        self.progress = nil
    }

    private struct BlockDownloadError: LocalizedError {
        let code: Int

        var errorDescription: String? {
            "File download failed. Error code: \(code)"
        }
    }
}
