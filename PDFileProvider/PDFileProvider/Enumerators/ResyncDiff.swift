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

import Foundation
import CoreData
import PDCore

/// The delete/update diff of a post-full-resync change enumeration: computed once (in the main app after
/// the metadata rebuild) and sliced per page (in the extension). Both arrays are pre-sorted by
/// `NodeIdentifier.rawValue`, the key the paged extension delivery uses.
public struct ResyncDiff: Codable, Equatable {
    public let deletes: [NodeIdentifier]
    public let updates: [NodeIdentifier]

    public init(deletes: [NodeIdentifier], updates: [NodeIdentifier]) {
        self.deletes = deletes
        self.updates = updates
    }
}

public extension ResyncDiff {
    /// On-disk artifact written by the main app and read by the extension. Distinct from the node-id
    /// snapshot (`tmp_node_ids.lz4`) so the two files never collide.
    static let resyncDiffTempFileName = "tmp_resync_diff.lz4"

    /// Partitions a resync-frozen node set into the delete/update stream.
    ///
    /// - `present` = `updateCandidates ∪ deletedState` (every node still in the store).
    /// - `deletes` = `(previous − present) ∪ deletedState`, deduped by `NodeIdentifier`'s `Hashable`
    ///   (rawValue-based: `nodeID/shareID` on macOS), sorted by `rawValue`.
    /// - `updates` = `updateCandidates` (present, non-deleted), sorted by `rawValue`.
    ///
    /// Dedup uses `NodeIdentifier`'s own `Hashable`. It derives `Hashable`/`Equatable`/`Codable` from its
    /// `RawRepresentable` conformance, so on macOS identity is `rawValue` ("nodeID/shareID") and `volumeID`
    /// is not part of it — two identifiers differing only in `volumeID` are the same identifier.
    static func computeResyncDiff(
        previous: [NodeIdentifier],
        updateCandidates: [NodeIdentifier],
        deletedState: [NodeIdentifier]
    ) -> ResyncDiff {
        var present = Set(updateCandidates)
        present.formUnion(deletedState)

        var deletes = Set(previous)
        deletes.subtract(present)
        deletes.formUnion(deletedState)

        let sortedDeletes = deletes.sorted { $0.rawValue < $1.rawValue }
        let sortedUpdates = updateCandidates.sorted { $0.rawValue < $1.rawValue }
        return ResyncDiff(deletes: sortedDeletes, updates: sortedUpdates)
    }

    /// Scans a metadata store on `moc`'s queue, partitioning present nodes into non-deleted update
    /// candidates and deleted-state identifiers — the inputs to `computeResyncDiff`. Shared by the main-app
    /// precompute and the extension fallback scan so both build the same diff.
    static func scanIdentifiers(in moc: NSManagedObjectContext, batchSize: Int) async throws
        -> (updateCandidates: [NodeIdentifier], deletedState: [NodeIdentifier]) {
        try await moc.perform(schedule: .immediate) {
            let fetchRequest = NSFetchRequest<Node>()
            fetchRequest.entity = NSEntityDescription.entity(forEntityName: "Node", in: moc)
            fetchRequest.fetchBatchSize = batchSize
            // Fetch only the columns the identity + state partition needs (mirrors
            // StorageManager.fetchAllNodeIdentifiers, plus stateRaw). Computed shareId still resolves
            // SharedWithMe nodes by faulting their share relationship — only for those few.
            fetchRequest.propertiesToFetch = ["id", "shareID", "volumeID", "stateRaw"]
            fetchRequest.returnsObjectsAsFaults = false
            let nodes = try moc.fetch(fetchRequest)
            var updateCandidates: [NodeIdentifier] = []
            var deletedState: [NodeIdentifier] = []
            updateCandidates.reserveCapacity(nodes.count)
            for node in nodes {
                let identifier = node.identifierWithinManagedObjectContext
                if node.state == .deleted {
                    deletedState.append(identifier)
                } else {
                    updateCandidates.append(identifier)
                }
            }
            return (updateCandidates, deletedState)
        }
    }

    /// Encodes to the on-disk artifact format (JSON + LZ4), mirroring
    /// `ResyncEnumerationService.compressedData(for:)`.
    func encoded() throws -> Data {
        let data = try JSONEncoder().encode(self) as NSData
        return try data.compressed(using: ResyncEnumerationService.nodeIdentifiersTempFileCompressionAlgorithm) as Data
    }

    /// Decodes from the artifact format written by `encoded()`, mirroring
    /// `ResyncEnumerationService.decodeNodeIdentifiers(from:)`.
    static func decode(from data: Data) throws -> ResyncDiff {
        let decompressed = try (data as NSData)
            .decompressed(using: ResyncEnumerationService.nodeIdentifiersTempFileCompressionAlgorithm) as Data
        return try JSONDecoder().decode(ResyncDiff.self, from: decompressed)
    }
}

extension ResyncDiff {
    /// Holds one computed `ResyncDiff` for reuse across the stateless per-page calls of a single resync
    /// run, keyed on the source snapshot's stat. Thread-safe. `compute` runs outside the lock, so the diff
    /// is computed at most once per key only for sequential callers (today's per-page usage); two concurrent
    /// misses would each compute.
    final class Cache {
        /// Stat of the on-disk snapshot the diff was derived from. A new run writes a new snapshot with a
        /// different stat, which invalidates the cache.
        struct Key: Equatable {
            let modificationDate: Date
            let size: Int

            init(fileURL: URL) throws {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                self.modificationDate = (attributes[.modificationDate] as? Date) ?? .distantPast
                self.size = (attributes[.size] as? Int) ?? -1
            }
        }

        private let lock = NSLock()
        private var cached: ResyncDiff?
        private var cachedKey: Key?
        /// Times the diff was computed (cache miss). Test seam for compute-once.
        private(set) var computationCount = 0

        init() {}

        /// Whether a diff is currently cached.
        var isPopulated: Bool {
            lock.lock(); defer { lock.unlock() }
            return cached != nil
        }

        /// Returns the cached diff when `key` matches, otherwise runs `compute`, stores it, and returns it.
        func diff(forKey key: Key, compute: () async throws -> ResyncDiff) async rethrows -> ResyncDiff {
            lock.lock()
            if cachedKey == key, let cached {
                lock.unlock()
                return cached
            }
            lock.unlock()

            let diff = try await compute()

            lock.lock()
            cached = diff
            cachedKey = key
            computationCount += 1
            lock.unlock()
            return diff
        }

        /// Drops the cached diff.
        func clear() {
            lock.lock(); defer { lock.unlock() }
            cached = nil
            cachedKey = nil
        }
    }
}
