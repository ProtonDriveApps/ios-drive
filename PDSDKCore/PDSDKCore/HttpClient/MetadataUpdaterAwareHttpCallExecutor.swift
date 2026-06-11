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
import ProtonCoreAuthentication
import ProtonCoreServices
import ProtonCoreNetworking
import PDCore
import ProtonDriveSDK

public protocol MetadataUpdaterAwareHttpCallExecutor {
    /// Drive api calls (takes `/drive/...` path)
    func requestDriveApi(
        method: String,
        relativePath: String,
        content: Data,
        headers: [(String, [String])],
        metadataUpdater: MetadataUpdaterProtocol,
        retryConfiguration: HttpClientResilience.Configuration,
        rateLimitGate: RateLimitGate
    ) async -> Result<HttpClientResponse, NSError>

    /// Raw request (takes whole url) - should be storage request
    func requestUploadToStorage(
        method: String,
        url: String,
        content: StreamForUpload,
        headers: [(String, [String])],
        retryConfiguration: HttpClientResilience.Configuration,
        rateLimitGate: RateLimitGate
    ) async -> Result<HttpClientResponse, NSError>

    func requestDownloadFromStorage(
        method: String,
        url: String,
        content: Data,
        headers: [(String, [String])],
        retryConfiguration: HttpClientResilience.Configuration,
        rateLimitGate: RateLimitGate,
        downloadStreamCreator: @Sendable @escaping (URLSession.AsyncBytes) -> AnyAsyncSequence<UInt8>
    ) async -> Result<HttpClientStream, NSError>
}

/// Family identifiers used by this layer when feeding the shared 429 gate.
/// Storage requests don't have semantic URL structure, so they get static keys
/// instead of the path-based `RateLimitFamily.from(method:path:)`.
enum StorageRateLimitFamily {
    static let upload = "storageUpload"
    static let download = "storageDownload"
}

func extractHeaders(fromAllHeaderFields allHeaderFields: [AnyHashable: Any]) -> [(String, [String])] {
    allHeaderFields.map { key, value in
        let extractedValues: [String]
        switch value {
        case let strings as [String]:
            extractedValues = strings
        case let values as [Any]:
            extractedValues = values.map(String.init(describing:))
        default:
            extractedValues = [String(describing: value)]
        }
        return (String(describing: key), extractedValues)
    }
}

// TODO(SDK): clean up force casts etc
extension PMAPIService: MetadataUpdaterAwareHttpCallExecutor {

    /// Make the Proton Core HTTP client conform to the SDK HTTP client protocol
    public func requestDriveApi(
        method: String,
        relativePath: String,
        content: Data,
        headers: [(String, [String])],
        metadataUpdater: MetadataUpdaterProtocol,
        retryConfiguration: HttpClientResilience.Configuration,
        rateLimitGate: RateLimitGate
    ) async -> Result<HttpClientResponse, NSError> {
        Log.debug("sdk request (drive): \(relativePath), headers: \(headers), content: \(String(data: content, encoding: .utf8) ?? "\(content.count) bytes")", domain: .sdk)

        // Same `(method, path) → family` mapping PDClient endpoints use, so a 429
        // observed here also blocks PDClient calls for the same resource shape.
        let family = RateLimitFamily.from(method: method, path: relativePath)

        return await HttpClientResilience.performWithResilience(
            configuration: retryConfiguration,
            rateLimitGate: rateLimitGate,
            family: family,
            refreshCredentials: performRequestToRefreshCredentials()
        ) { [weak self] previousError in
            guard let self else {
                let error = (previousError ?? CocoaError(.userCancelled)) as NSError
                return .doNotRetry(.failure(error))
            }
            let result = await self.executeDriveAPICall(
                method: method, path: relativePath, content: content, headers: headers, metadataUpdater: metadataUpdater
            )
            return .retryIfNeeded(result)
        }
    }

    public func requestUploadToStorage(
        method: String,
        url: String,
        content: StreamForUpload,
        headers: [(String, [String])],
        retryConfiguration: HttpClientResilience.Configuration,
        rateLimitGate: RateLimitGate
    ) async -> Result<HttpClientResponse, NSError> {
        Log.debug("upload request: \(url), headers: \(headers)", domain: .sdk)

        let uploader = SDKURLSessionStreamingUploader()

        return await HttpClientResilience.performWithResilience(
            configuration: retryConfiguration,
            rateLimitGate: rateLimitGate,
            family: StorageRateLimitFamily.upload,
            refreshCredentials: performRequestToRefreshCredentials()
        ) { [weak self] previousError in
            guard let self else {
                let error = (previousError ?? CocoaError(.userCancelled)) as NSError
                return .doNotRetry(.failure(error))
            }
            return await executeUpload(
                uploader: uploader,
                method: method,
                url: url,
                content: content,
                headers: headers,
                retryConfiguration: retryConfiguration,
                previousError: previousError
            )
        }
    }

    public func requestDownloadFromStorage(
        method: String,
        url: String,
        content: Data,
        headers: [(String, [String])],
        retryConfiguration: HttpClientResilience.Configuration,
        rateLimitGate: RateLimitGate,
        downloadStreamCreator: @Sendable @escaping (URLSession.AsyncBytes) -> AnyAsyncSequence<UInt8>
    ) async -> Result<HttpClientStream, NSError> {
        Log.debug("download request: \(url), headers: \(headers), content: \(String(data: content, encoding: .utf8) ?? "\(content.count) bytes")", domain: .sdk)

        let downloader = SDKURLSessionStreamingDownloader(downloadStreamCreator: downloadStreamCreator)

        return await HttpClientResilience.performWithResilience(
            configuration: retryConfiguration,
            rateLimitGate: rateLimitGate,
            family: StorageRateLimitFamily.download,
            refreshCredentials: performRequestToRefreshCredentials()
        ) { [weak self] previousError in
            guard let self else {
                let error = (previousError ?? CocoaError(.userCancelled)) as NSError
                return .doNotRetry(.failure(error))
            }

            let result = await executeDownload(
                downloader: downloader,
                method: method,
                url: url,
                content: content,
                headers: headers,
                retryConfiguration: retryConfiguration
            )
            return .retryIfNeeded(result)
        }
    }
    
    private func performRequestToRefreshCredentials() -> (Error) async throws -> Void {
        { [weak self] error in
            guard let self else { throw error }
            // We don't perform the refresh call directly, because there might be another refresh call racing against it.
            // So what we do instead, we perform a "dummy" request to kick off the synchronized refresh call.
            // User info request requires fresh credentials, so it will cause a synchronized refresh call to happen.
            // It's a workaround against the PMAPIService sychronized refresh mechanism being not public.
            let authenticator = Authenticator(api: self)
            _ = try await authenticator.getUserInfo()
        }
    }
    
    private func executeDriveAPICall(
        method: String,
        path: String,
        content: Data,
        headers requestHeaders: [(String, [String])],
        metadataUpdater: MetadataUpdaterProtocol
    ) async -> Result<HttpClientResponse, NSError> {
        // Check if the task was cancelled before starting the request
        if Task.isCancelled {
            return .failure(URLError(.cancelled) as NSError)
        }
        var dataTask: URLSessionDataTask?
        return await withTaskCancellationHandler {
            return await withCheckedContinuation { continuation in
                do {
                    let parameters: JSONDictionary?
                    if content.isEmpty {
                        parameters = nil
                    } else {
                        parameters = try JSONSerialization.jsonObject(with: content) as? JSONDictionary ?? nil
                    }
                    guard let method = HTTPMethod(rawValue: method) else {
                        assertionFailure("Unknown HTTP method type \(method)")
                        throw URLError(.unsupportedURL)
                    }
                    let headers = headersMap(requestHeaders)
                    self.request(
                        method: method,
                        path: path,
                        parameters: parameters,
                        headers: headers,
                        authenticated: true,
                        authRetry: true,
                        customAuthCredential: nil,
                        nonDefaultTimeout: 604_800,
                        // we opt-out from the PMAPIService retry policy because we have a custom resilience
                        retryPolicy: .userInitiated,
                        onDataTaskCreated: { dataTask = $0 },
                        jsonCompletion: { _, result in
                            do {
                                switch result {
                                case .success(let jsonDictionary):
                                    guard let httpResponse = dataTask?.response as? HTTPURLResponse else {
                                        throw URLError(.badServerResponse)
                                    }
                                    
                                    let response = try Self.handleDriveAPICallResponse(
                                        path, method, requestHeaders, parameters, httpResponse, jsonDictionary, metadataUpdater
                                    )
                                    continuation.resume(returning: response)
                                    
                                case .failure(let error):
                                    guard let httpResponse = dataTask?.response as? HTTPURLResponse else {
                                        throw error
                                    }
                                    
                                    guard let jsonDictionary = error.userInfo[ResponseError.responseDictionaryUserInfoKey] as? JSONDictionary else {
                                        let responseHeaders = Self.extractHeaders(from: httpResponse)
                                        let response = HttpClientResponse(data: nil, headers: responseHeaders, statusCode: httpResponse.statusCode)
                                        continuation.resume(returning: .success(response))
                                        return
                                    }
                                    
                                    let response = try Self.handleDriveAPICallResponse(
                                        path, method, requestHeaders, parameters, httpResponse, jsonDictionary, metadataUpdater
                                    )
                                    continuation.resume(returning: response)
                                }
                            } catch {
                                continuation.resume(returning: .failure(error as NSError))
                            }
                        })
                } catch {
                    continuation.resume(returning: .failure(error as NSError))
                }
            }
        } onCancel: {
            dataTask?.cancel()
        }
    }
    
    static private func handleDriveAPICallResponse(
        _ path: String,
        _ method: HTTPMethod,
        _ requestHeaders: [(String, [String])],
        _ parameters: JSONDictionary?,
        _ httpResponse: HTTPURLResponse,
        _ jsonDictionary: JSONDictionary,
        _ metadataUpdater: MetadataUpdaterProtocol
    ) throws -> Result<HttpClientResponse, NSError> {
        let responseHeaders = extractHeaders(from: httpResponse)
        let data = try JSONSerialization.data(withJSONObject: jsonDictionary, options: [])
        let statusCode = httpResponse.statusCode
        metadataUpdater.handleRequestAndResponse(
            path: path,
            method: method,
            requestHeaders: requestHeaders,
            requestBody: parameters,
            responseStatusCode: statusCode,
            responseHeaders: responseHeaders,
            responseBody: jsonDictionary
        )
        let response = HttpClientResponse(data: data, headers: responseHeaders, statusCode: statusCode)
        return .success(response)
    }
    
    private func executeUpload(
        uploader: SDKURLSessionStreamingUploader,
        method: String,
        url: String,
        content: StreamForUpload,
        headers: [(String, [String])],
        retryConfiguration: HttpClientResilience.Configuration,
        previousError: Error? = nil
    ) async -> ParticipateInRetries<HttpClientResponse> {
        // Check if the task was cancelled before starting the upload
        if Task.isCancelled {
            return .doNotRetry(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        }
        
        let updatedHeaders = await addHeadersToRawStorageCall(headers: headers)
        let request = await createRequest(url: url, method: method, headers: updatedHeaders)
        
        Log.debug("Uploading request: \(request)", domain: .sdk)
        
        // if the stream used for HTTP request body was already read from, we don't retry
        guard content.input.streamStatus == .notOpen else {
            Log.debug("HttpClientResilience: not retrying upload due to already written stream", domain: .networking)
            let error = (previousError ?? CocoaError(.userCancelled)) as NSError
            return .retryIfNeeded(.failure(error))
        }

        do {
            let result = try await uploader.upload(
                streamedRequest: request,
                streamForUpload: content
            )
            return .retryIfNeeded(result)
        } catch {
            return .retryIfNeeded(.failure(error as NSError))
        }
    }
    
    private func executeDownload(
        downloader: SDKURLSessionStreamingDownloader,
        method: String,
        url: String,
        content: Data,
        headers: [(String, [String])],
        retryConfiguration: HttpClientResilience.Configuration
    ) async -> Result<HttpClientStream, NSError> {
        // Check if the task was cancelled before starting the upload
        if Task.isCancelled {
            return .failure(URLError(.cancelled) as NSError)
        }
        
        let updatedHeaders = await addHeadersToRawStorageCall(headers: headers)
        let request = await createRequest(url: url, method: method, headers: updatedHeaders)
        Log.debug("Downloading request: \(request)", domain: .sdk)
        return await downloader.download(request: request)
    }
    
    private func addHeadersToRawStorageCall(
        headers: [(String, [String])]
    ) async -> [(String, [String])] {
        var updatedHeaders = headers
        
        if let serviceDelegate {
            updatedHeaders.append(("x-pm-appversion", [serviceDelegate.appVersion]))
            updatedHeaders.append(("x-pm-locale", [serviceDelegate.locale]))
            if let userAgent = serviceDelegate.userAgent {
                updatedHeaders.append(("User-Agent", [userAgent]))
            }
            if let additionalHeaders = serviceDelegate.additionalHeaders {
                additionalHeaders.forEach { updatedHeaders.append(($0, [$1])) }
            }
        } else {
            assertionFailure("PMAPIService must have service delegate set")
        }
        
        updatedHeaders.append(("x-pm-uid", [sessionUID]))
        switch await fetchAuthCredentials() {
        case .found(let credentials):
            updatedHeaders.append(("Authorization", ["Bearer \(credentials.accessToken)"]))
        case .notFound, .wrongConfigurationNoDelegate:
            if (authDelegate as? PMAPIClient)?.isSignedIn() == true {
                assertionFailure("The storage calls should always be performed with valid credentials")
            }
            break
        }
        
        return updatedHeaders
    }
    
    fileprivate func createRequest(url: String, method: String, headers: [(String, [String])]) async -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.timeoutInterval = 604_800
        request.httpMethod = method
        for header in headers {
            var values = header.1
            guard !values.isEmpty else { continue }
            let firstValue = values.removeFirst()
            request.setValue(firstValue, forHTTPHeaderField: header.0)
            if !values.isEmpty {
                values.forEach { value in
                    request.addValue(value, forHTTPHeaderField: header.0)
                }
            }
        }
        return request
    }
    
    /// Extract response headers without going through Alamofire's HTTPHeaders (which does O(n²) dedup)
    static func extractHeaders(from response: HTTPURLResponse) -> [(String, [String])] {
        PDSDKCore.extractHeaders(fromAllHeaderFields: response.allHeaderFields)
    }

    /// Map headers from the array of tuples provided by the SDK to a dictionary required by Proton Core Networking
    private func headersMap(_ headers: [(String, [String])]) -> [String: Any] {
        var map: [String: Any] = [:]
        for (key, values) in headers {
            if values.count == 1 {
                map[key] = values[0]
            } else {
                map[key] = values
            }
        }
        return map
    }
}
