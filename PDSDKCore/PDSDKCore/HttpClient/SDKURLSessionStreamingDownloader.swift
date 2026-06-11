// Copyright (c) 2025 Proton AG
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
import ProtonDriveSDK

final class SDKURLSessionStreamingDownloader: Sendable {
    private weak var task: URLSessionDataTask?
    
    private let session: URLSession
    private let downloadStreamCreator: @Sendable (URLSession.AsyncBytes) -> AnyAsyncSequence<UInt8>
    
    init(session: URLSession = DefaultURLSessionProvider.instance.session,
         downloadStreamCreator: @Sendable @escaping (URLSession.AsyncBytes) -> AnyAsyncSequence<UInt8>) {
        self.session = session
        self.downloadStreamCreator = downloadStreamCreator
    }
    
    func download(request: URLRequest) async -> Result<HttpClientStream, NSError> {
        await withTaskCancellationHandler {
            do {
                let (bytes, urlResponse) = try await session.bytes(for: request)
                
                self.task = bytes.task
                
                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    throw URLSessionInvalidRepresentationError()
                }
                
                let response = HttpClientStream(
                    stream: downloadStreamCreator(bytes),
                    headers: httpResponse.headers.dictionary.map { ($0.key, [$0.value]) },
                    statusCode: httpResponse.statusCode
                )
                return .success(response)
            } catch {
                return .failure(error as NSError)
            }
        } onCancel: { [weak self] in
            // When parent Task is cancelled, this handler is called automatically,
            // cancelling the URLSessionDataTask.
            self?.cancel()
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
    
    deinit {
        task = nil
    }
}
