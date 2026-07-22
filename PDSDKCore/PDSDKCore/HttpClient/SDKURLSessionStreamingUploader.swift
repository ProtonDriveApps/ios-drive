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
import PDCore

final class SDKURLSessionStreamingUploader: @unchecked Sendable {
    weak var task: URLSessionUploadTask?
    var delegate: StreamingDelegate?

    private let urlSessionDelegate: URLSessionTaskDelegate?
    private let session: URLSession

    init(session: URLSession = DefaultURLSessionProvider.instance.session,
         urlSessionDelegate: URLSessionTaskDelegate = DefaultURLSessionProvider.instance.delegate) {
        self.urlSessionDelegate = urlSessionDelegate
        self.session = session
    }

    func upload(
        streamedRequest: URLRequest,
        streamForUpload: StreamForUpload
    ) async throws -> Result<HttpClientResponse, NSError> {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { [weak self] continuation in
                guard let self else {
                    return continuation.resume(returning: .failure(CocoaError(.userCancelled) as NSError))
                }

                let boxedContinuation = BoxedThrowingContinuation(continuation)

                // this `URLSessionUploadTask` retains the `data` even after the request is completed, unit task is released
                let uploadTask = session.uploadTask(withStreamedRequest: streamedRequest)

                let streamingDelegate = StreamingDelegate(
                    streamForUpload: streamForUpload,
                    delegate: urlSessionDelegate
                ) { [weak self] data, response, error in
                    guard let self else {
                        return
                    }
                    let result = (self.parse(response, data: data, error: error as? NSError))
                    self.delegate = nil
                    boxedContinuation.resume(returning: result)
                }
                streamForUpload.onStreamError = { [weak self] error in
                    guard let self else {
                        return
                    }
                    self.delegate = nil
                    boxedContinuation.resume(returning: .failure(error as NSError))
                }
                delegate = streamingDelegate
                task = uploadTask
                uploadTask.delegate = streamingDelegate
                uploadTask.resume()
            }
        } onCancel: { [weak self] in
            // When parent Task is cancelled, this handler is called automatically,
            // cancelling the URLSessionUploadTask.
            self?.cancel()
        }
    }

    func cancel() {
        task?.cancel()
        delegate = nil
    }

    deinit {
        task = nil
    }

    private func parse(
        _ urlResponse: URLResponse?,
        data: Data?,
        error: NSError?
    ) -> Result<HttpClientResponse, NSError> {
        if let error {
            return .failure(error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            let error = error ?? (URLSessionInvalidRepresentationError() as NSError)
            return .failure(error)
        }

        let response = HttpClientResponse(
            data: data!,
            headers: httpResponse.headers.dictionary.map { ($0.key, [$0.value]) },
            statusCode: httpResponse.statusCode
        )
        return .success(response)
    }
}

private final class BoxedThrowingContinuation<ResultType> {
    private var continuation: CheckedContinuation<ResultType, Error>?

    init(_ continuation: CheckedContinuation<ResultType, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: sending ResultType) {
        guard let continuation else { return }
        continuation.resume(returning: value)
        self.continuation = nil
    }
}

struct URLSessionInvalidRepresentationError: Error {}

final class StreamingDelegate: NSObject, URLSessionDataDelegate {

    let streamForUpload: StreamForUpload
    let delegate: URLSessionTaskDelegate?
    var responseData: Data = Data()
    let completionBlock: (Data?, URLResponse?, Error?) -> Void

    init(streamForUpload: StreamForUpload,
         delegate: URLSessionTaskDelegate?,
         completionBlock: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.streamForUpload = streamForUpload
        self.delegate = delegate
        self.completionBlock = completionBlock
    }

    func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
        streamForUpload.openOutputStream()
        return streamForUpload.input
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        Log.debug("[URLSession.didCompleteWithError] url: \(task.originalRequest?.url?.absoluteString ?? "???"), error: \(error?.localizedDescription ?? "none"))", domain: .networking)
        // We pass the input to URLSession in needNewBodyStreamForTask. It opens it.
        // URLSession's docs don't promise to close it, so we do it here.
        streamForUpload.input.close()
        completionBlock(responseData, task.response, error)
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        delegate?.urlSession?(
            session,
            didReceive: challenge,
            completionHandler: completionHandler
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        delegate?.urlSession?(
            session,
            task: task,
            didReceive: challenge,
            completionHandler: completionHandler
        )
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseData.append(data)
    }
}
