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
    typealias TokenCanceller = (UUID) async -> Void

    private struct PendingRequest {
        let identifier: AnyVolumeIdentifier
        let continuation: CheckedContinuation<AnyVolumeIdentifier?, any Error>
    }

    private struct InFlightBatch {
        let requests: [PendingRequest]
        let type: ThumbnailType
        var resolvedIndices: Set<Int> = []
    }

    private let cacheResource: ThumbnailsDownloadLocalCacheProtocol
    private let managedObjectContext: NSManagedObjectContext
    private let tokenStore: ThumbnailsDownloadTokensCache
    private let streamFactory: StreamFactory
    private let tokenCanceller: TokenCanceller

    private var pendingByType: [ThumbnailType: [PendingRequest]] = [:]
    private var flushTasksByType: [ThumbnailType: Task<Void, Never>] = [:]
    private var inFlightBatches: [UUID: InFlightBatch] = [:]
    private var emptyThumbnails: [AnyVolumeIdentifier] = []

    private let maxBatchSize = 30
    private static let flushWindowMilliseconds: any BinaryInteger = 50

    init(
        cacheResource: ThumbnailsDownloadLocalCacheProtocol,
        managedObjectContext: NSManagedObjectContext,
        tokenStore: ThumbnailsDownloadTokensCache,
        streamFactory: @escaping StreamFactory,
        tokenCanceller: @escaping TokenCanceller
    ) {
        self.cacheResource = cacheResource
        self.managedObjectContext = managedObjectContext
        self.tokenStore = tokenStore
        self.streamFactory = streamFactory
        self.tokenCanceller = tokenCanceller
    }

    // MARK: - Public

    func downloadThumbnail(
        file identifier: AnyVolumeIdentifier,
        type: ThumbnailType
    ) async throws -> AnyVolumeIdentifier? {
        if emptyThumbnails.contains(identifier) { return nil }
        return try await withCheckedThrowingContinuation { continuation in
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

    func cancelAll() async {
        for task in flushTasksByType.values {
            task.cancel()
        }
        flushTasksByType.removeAll()

        let pending = pendingByType
        pendingByType.removeAll()
        for requests in pending.values {
            for request in requests {
                request.continuation.resume(throwing: CancellationError())
            }
        }

        let batches = inFlightBatches
        inFlightBatches.removeAll()

        var tokensToCancel = Set<UUID>()
        for (batchToken, batch) in batches {
            tokensToCancel.insert(batchToken)
            for (index, request) in batch.requests.enumerated() where !batch.resolvedIndices.contains(index) {
                await tokenStore.remove(for: request.identifier, type: batch.type)
                request.continuation.resume(throwing: CancellationError())
            }
        }

        let remainingTokens = await tokenStore.removeAll()
        tokensToCancel.formUnion(Set(remainingTokens))

        for token in tokensToCancel {
            await tokenCanceller(token)
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

        let batchToken = UUID()
        inFlightBatches[batchToken] = InFlightBatch(requests: requests, type: type)

        Task { [weak self] in
            await self?.performBatchDownload(batchToken: batchToken, requests: requests, type: type)
        }
    }

    // MARK: - Batch download

    private func performBatchDownload(batchToken: UUID, requests: [PendingRequest], type: ThumbnailType) async {
        defer { inFlightBatches.removeValue(forKey: batchToken) }

        for request in requests {
            await tokenStore.setToken(batchToken, for: request.identifier, type: type)
        }
        Log.info("Batch download \(requests.count) thumbnails", domain: .thumbnails)

        do {
            let stream = streamFactory(
                requests.map { $0.identifier.sdkUid },
                type.sdkThumbnailType,
                batchToken,
                managedObjectContext
            )

            for try await thumbnail in stream {
                guard let thumbnail else {
                    Log.debug("Skip because thumbnail data is nil", domain: .thumbnails)
                    continue
                }
                let identifier = thumbnail.fileUid.any
                await tokenStore.remove(for: identifier, type: type)
                switch thumbnail.result {
                case .failure(let error):
                    if error.localizedDescription.hasSuffix("has no thumbnails") {
                        emptyThumbnails.append(identifier)
                    }
                    resolveBatchRequests(
                        batchToken: batchToken,
                        matching: identifier,
                        result: .failure(error)
                    )
                case .success:
                    try await cacheResource.storeThumbnails([thumbnail], type: type)
                    resolveBatchRequests(
                        batchToken: batchToken,
                        matching: identifier,
                        result: .success(identifier)
                    )
                }
            }

            // Stream completed — resume any requests the server did not yield a thumbnail for.
            await resolveUnresolvedBatchRequests(batchToken: batchToken) { request in
                Log.warning(
                    "Thumbnail stream completed without yield for \(request.identifier.debugDesc), type: \(type), token: \(batchToken.uuidString)",
                    domain: .thumbnails
                )
                request.continuation.resume(returning: nil)
            }
            Log.info("Batch download of \(requests.count) thumbnails finished", domain: .thumbnails)
        } catch {
            Log.error("Batch download thumbnail failed", error: error, domain: .thumbnails)
            await resolveUnresolvedBatchRequests(batchToken: batchToken) { request in
                request.continuation.resume(throwing: error)
            }
        }
    }

    private func resolveBatchRequests(
        batchToken: UUID,
        matching identifier: AnyVolumeIdentifier,
        result: Result<AnyVolumeIdentifier, any Error>
    ) {
        guard var batch = inFlightBatches[batchToken] else { return }

        for (index, request) in batch.requests.enumerated()
            where !batch.resolvedIndices.contains(index) && request.identifier == identifier {
            batch.resolvedIndices.insert(index)
            inFlightBatches[batchToken] = batch

            switch result {
            case .success(let id):
                request.continuation.resume(returning: id)
            case .failure(let error):
                request.continuation.resume(throwing: error)
            }
        }
    }

    private func resolveUnresolvedBatchRequests(
        batchToken: UUID,
        resolve: (PendingRequest) -> Void
    ) async {
        guard var batch = inFlightBatches[batchToken] else { return }

        for (index, request) in batch.requests.enumerated() where !batch.resolvedIndices.contains(index) {
            batch.resolvedIndices.insert(index)
            inFlightBatches[batchToken] = batch
            await tokenStore.remove(for: request.identifier, type: batch.type)
            resolve(request)
        }
    }
}
