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
import ProtonDriveSDK
import PDCore
import ProtonCoreNetworking
import ProtonCoreServices

public final class HttpClient: HttpClientProtocol, @unchecked Sendable {
    private let apiService: MetadataUpdaterAwareHttpCallExecutor
    private let metadataUpdater: MetadataUpdaterProtocol
    private let httpResilience: HttpResilienceConfigurationProvider
    private let urlCacheCleaner: URLCacheCleanerProtocol
    private let rateLimitGate: RateLimitGate

    public init(apiService: MetadataUpdaterAwareHttpCallExecutor,
                metadataUpdater: MetadataUpdaterProtocol,
                httpResilience: HttpResilienceConfigurationProvider,
                urlCacheCleaner: URLCacheCleanerProtocol,
                rateLimitGate: RateLimitGate) {
        self.apiService = apiService
        self.metadataUpdater = metadataUpdater
        self.httpResilience = httpResilience
        self.urlCacheCleaner = urlCacheCleaner
        self.rateLimitGate = rateLimitGate
    }

    public func requestDriveApi(
        method: String,
        relativePath: String,
        content: Data,
        headers: [(String, [String])]
    ) async -> Result<HttpClientResponse, NSError> {
        urlCacheCleaner.cleanCacheIfNeeded()
        return await apiService.requestDriveApi(
            method: method,
            relativePath: relativePath,
            content: content,
            headers: headers,
            metadataUpdater: metadataUpdater,
            retryConfiguration: httpResilience.retryConfiguration(for: .regularApi),
            rateLimitGate: rateLimitGate
        )
    }

    /// Raw request (takes whole url) - should be storage request
    public func requestUploadToStorage(
        method: String,
        url: String,
        content: StreamForUpload,
        headers: [(String, [String])]
    ) async -> Result<HttpClientResponse, NSError> {
        await apiService.requestUploadToStorage(
            method: method,
            url: url,
            content: content,
            headers: headers,
            retryConfiguration: httpResilience.retryConfiguration(for: .storageUpload),
            rateLimitGate: rateLimitGate
        )
    }

    public func requestDownloadFromStorage(
        method: String,
        url: String,
        content: Data,
        headers: [(String, [String])],
        downloadStreamCreator: @Sendable @escaping (URLSession.AsyncBytes) -> AnyAsyncSequence<UInt8>
    ) async -> Result<HttpClientStream, NSError> {
        await apiService.requestDownloadFromStorage(
            method: method,
            url: url,
            content: content,
            headers: headers,
            retryConfiguration: httpResilience.retryConfiguration(for: .storageDownload),
            rateLimitGate: rateLimitGate,
            downloadStreamCreator: downloadStreamCreator
        )
    }
}
