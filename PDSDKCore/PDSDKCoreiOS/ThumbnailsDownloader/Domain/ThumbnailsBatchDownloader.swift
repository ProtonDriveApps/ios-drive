// Copyright (c) 2026 Proton AG
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

import CoreData
import Foundation
import PDCore
import PDSDKCore
import ProtonDriveSDK

actor ThumbnailsBatchDownloader {
    typealias StreamFactory = ([SDKNodeUid], ThumbnailData.ThumbnailType, UUID, NSManagedObjectContext) -> AsyncThrowingStream<ThumbnailDataWithId?, Error>

    private struct PendingRequest {
        let identifier: AnyVolumeIdentifier
        let continuation: CheckedContinuation<AnyVolumeIdentifier?, any Error>
    }

    private let cacheResource: ThumbnailsDownloadLocalCacheProtocol
    private let managedObjectContext: NSManagedObjectContext
    private let tokenStore: ThumbnailsDownloadTokensCache
    private let streamFactory: StreamFactory

    private var pendingByType: [ThumbnailType: [PendingRequest]] = [:]
    private var flushTasksByType: [ThumbnailType: Task<Void, Never>] = [:]

    private let maxBatchSize = 30
    private static let flushWindowMilliseconds: any BinaryInteger = 50

    init(
        cacheResource: ThumbnailsDownloadLocalCacheProtocol,
        managedObjectContext: NSManagedObjectContext,
        tokenStore: ThumbnailsDownloadTokensCache,
        streamFactory: @escaping StreamFactory
    ) {
        self.cacheResource = cacheResource
        self.managedObjectContext = managedObjectContext
        self.tokenStore = tokenStore
        self.streamFactory = streamFactory
    }

    // MARK: - Public

    func downloadThumbnail(
        file identifier: AnyVolumeIdentifier,
        type: ThumbnailType
    ) async throws -> AnyVolumeIdentifier? {
        try await withCheckedThrowingContinuation { continuation in
            let request = PendingRequest(identifier: identifier, continuation: continuation)
            pendingByType[type, default: []].append(request)

            if pendingByType[type]?.count == 1 {
                scheduleFlush(for: type)
            }

            if pendingByType[type]?.count ?? 0 >= maxBatchSize {
                flush(for: type)
            }
        }
    }

    func cancel(file identifier: AnyVolumeIdentifier, type: ThumbnailType) async {
        // Only cancel requests that are still pending
        guard var pending = pendingByType[type] else { return }
        let cancelled = pending.filter { $0.identifier == identifier }
        guard !cancelled.isEmpty else { return }
        pending.removeAll { $0.identifier == identifier }
        pendingByType[type] = pending

        for request in cancelled {
            request.continuation.resume(throwing: CancellationError())
        }
    }

    // MARK: - Flush scheduling

    private func scheduleFlush(for type: ThumbnailType) {
        flushTasksByType[type]?.cancel()
        flushTasksByType[type] = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(Self.flushWindowMilliseconds))
                await self?.flush(for: type)
            } catch {}
        }
    }

    private func flush(for type: ThumbnailType) {
        let pendingRequests = pendingByType[type] ?? []
        if pendingRequests.isEmpty { return }

        // Cancel the current timer before draining.
        flushTasksByType[type]?.cancel()
        flushTasksByType[type] = nil

        let requests = Array(pendingRequests.prefix(maxBatchSize))
        pendingByType[type] = Array(pendingRequests.dropFirst(maxBatchSize))

        // Schedule another flush for any overflow that didn't fit in this batch.
        if pendingByType[type]?.count ?? 0 > 0 {
            scheduleFlush(for: type)
        }

        Task { [weak self] in
            await self?.performBatchDownload(requests, type: type)
        }
    }

    // MARK: - Batch download

    private func performBatchDownload(_ requests: [PendingRequest], type: ThumbnailType) async {
        let batchToken = UUID()
        for request in requests {
            await tokenStore.setToken(batchToken, for: request.identifier, type: type)
        }

        var resolvedIndices = Set<Int>()

        do {
            let stream = streamFactory(
                requests.map { $0.identifier.sdkUid },
                type.sdkThumbnailType,
                batchToken,
                managedObjectContext
            )

            for try await thumbnail in stream {
                guard let thumbnail else { continue }
                try await cacheResource.storeThumbnails([thumbnail], type: type)
                let identifier = thumbnail.fileUid.any
                await tokenStore.remove(for: identifier, type: type)
                resumeRequests(
                    in: requests,
                    matching: identifier,
                    type: type,
                    resolvedIndices: &resolvedIndices,
                    result: .success(identifier)
                )
            }

            // Stream completed — resume any requests the server did not yield a thumbnail for.
            for (index, request) in requests.enumerated() where !resolvedIndices.contains(index) {
                resolvedIndices.insert(index)
                Log.warning(
                    "Thumbnail stream completed without yield for \(request.identifier.debugDesc), type: \(type), token: \(batchToken.uuidString)",
                    domain: .sdk
                )
                await tokenStore.remove(for: request.identifier, type: type)
                request.continuation.resume(returning: nil)
            }
        } catch {
            for (index, request) in requests.enumerated() where !resolvedIndices.contains(index) {
                await tokenStore.remove(for: request.identifier, type: type)
                request.continuation.resume(throwing: error)
            }
        }
    }

    private func resumeRequests(
        in requests: [PendingRequest],
        matching identifier: AnyVolumeIdentifier,
        type: ThumbnailType,
        resolvedIndices: inout Set<Int>,
        result: Result<AnyVolumeIdentifier, any Error>
    ) {
        for (index, request) in requests.enumerated()
            where !resolvedIndices.contains(index) && request.identifier == identifier {
            resolvedIndices.insert(index)
            switch result {
            case .success(let id):
                request.continuation.resume(returning: id)
            case .failure(let error):
                request.continuation.resume(throwing: error)
            }
        }
    }
}
