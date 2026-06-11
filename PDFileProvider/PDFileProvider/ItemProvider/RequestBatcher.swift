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
import PDCore

public enum RequestBatcherError: Error, Equatable {
    case idNotInResponse
}

/// Coalesces concurrent per-item requests into batched flushes, bounded by a
/// per-bucket size cap and a first-arrival latency deadline (not reset by
/// later arrivals).
///
/// Each bucket carries a unique `id` captured by its timer. The timer's flush
/// path no-ops unless `buckets[key]?.id` still matches, so a stale timer left
/// over from a size-cap pop or cancel cannot drain a replacement bucket.
/// `Task.cancel()` is insufficient here — cancellation is cooperative and
/// racy with the post-sleep actor re-entry.
public actor RequestBatcher<Key: Hashable & Sendable, Item: Sendable, Output: Sendable> {

    public typealias FlushClosure = @Sendable ([Item], Key) async throws -> [String: Result<Output, Error>]

    private struct PendingRequest {
        let id: String
        let item: Item
        let continuation: CheckedContinuation<Output, Error>
    }

    private struct Bucket {
        let id = UUID()
        var requests: [PendingRequest] = []
    }

    private let maxBatchSize: Int
    private let maxLatency: Duration
    private let flush: FlushClosure
    private var buckets: [Key: Bucket] = [:]

    public init(
        maxBatchSize: Int = CloudSlot.maxBatchSize,
        maxLatency: Duration = .seconds(5),
        flush: @escaping FlushClosure
    ) {
        self.maxBatchSize = maxBatchSize
        self.maxLatency = maxLatency
        self.flush = flush
    }

    public func enqueue(item: Item, key: Key, id: String) async throws -> Output {
        // The continuation body runs synchronously on this actor before suspend
        // (SE-0300 + `#isolation`), so concurrent enqueues serialize as atomic turns.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Output, Error>) in
            let request = PendingRequest(id: id, item: item, continuation: continuation)
            var bucket = buckets[key] ?? Bucket()
            let isFirstInBucket = bucket.requests.isEmpty
            bucket.requests.append(request)

            guard bucket.requests.count < maxBatchSize else {
                // Pop atomically so the next enqueue starts a fresh bucket
                // and the cap holds under bursts.
                buckets.removeValue(forKey: key)
                let popped = bucket
                Task { [weak self] in
                    await self?.runFlush(bucket: popped, key: key)
                }
                return
            }

            if isFirstInBucket {
                let latency = maxLatency
                let bucketID = bucket.id
                Task { [weak self] in
                    try? await Task.sleep(for: latency)
                    await self?.flushIfPending(key: key, bucketID: bucketID)
                }
            }
            buckets[key] = bucket
        }
    }

    /// Used by tests to wait until enqueued items are visible in the bucket
    /// before issuing `cancel`.
    public func pendingItemCount(key: Key) -> Int {
        buckets[key]?.requests.count ?? 0
    }

    public func cancel(id: String, key: Key) {
        guard var bucket = buckets[key],
              let index = bucket.requests.firstIndex(where: { $0.id == id }) else {
            return
        }
        let request = bucket.requests.remove(at: index)
        if bucket.requests.isEmpty {
            buckets.removeValue(forKey: key)
        } else {
            buckets[key] = bucket
        }
        request.continuation.resume(throwing: CancellationError())
    }

    private func flushIfPending(key: Key, bucketID: UUID) async {
        guard let bucket = buckets[key], bucket.id == bucketID else {
            return
        }
        buckets.removeValue(forKey: key)
        await runFlush(bucket: bucket, key: key)
    }

    private func runFlush(bucket: Bucket, key: Key) async {
        let items = bucket.requests.map(\.item)
        do {
            let results = try await flush(items, key)
            for request in bucket.requests {
                if let result = results[request.id] {
                    request.continuation.resume(with: result)
                } else {
                    request.continuation.resume(throwing: RequestBatcherError.idNotInResponse)
                }
            }
        } catch {
            for request in bucket.requests {
                request.continuation.resume(throwing: error)
            }
        }
    }
}
