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

import CoreData
import PDClient
import ProtonCoreNetworking

/// Fetches and updates a node's latest metadata in the given context. Throws if the fetch fails.
public typealias NodeMetadataRefreshing = (NodeIdentifier, NSManagedObjectContext) async throws -> Void

/// Raised by the out-of-sync recovery when the metadata refresh reveals the node no longer exists on the backend.
public enum OutOfSyncRecoveryError: Error {
    case nodeRemoved
}

extension Error {
    /// True when move/rename was rejected because the client's view of the node is stale (OriginalHash mismatch).
    /// The concrete check lives on `ResponseError` (see `ResponseError+Extension`).
    var isDriveItemOutOfSync: Bool {
        (self as? ResponseError)?.isDriveItemOutOfSync ?? false
    }
}

/// Shared "item out of sync" (error 2000) recovery for the File-Provider move/rename operations.
///
/// Runs `attempt`. When it fails with a 2000 and a `metadataRefresher` is present (macOS), the node's
/// metadata is refreshed once and then:
/// - a refresher failure rethrows the **original** 2000 (not the refresher's error);
/// - if the refresh hard-deleted the node (the backend no longer has it), throws `OutOfSyncRecoveryError.nodeRemoved`
///   — a trashed node still exists and is **not** treated as removed;
/// - if the refreshed state makes the operation unnecessary (`stillNeeded == false`), returns without retrying;
/// - otherwise retries `attempt` exactly once.
///
/// With no refresher (iOS) `attempt` runs once and any error propagates unchanged.
func performWithOutOfSyncRetry(
    node: Node,
    moc: NSManagedObjectContext,
    metadataRefresher: NodeMetadataRefreshing?,
    attempt: () async throws -> Void,
    stillNeeded: () async throws -> Bool
) async throws {
    guard let metadataRefresher else {
        try await attempt()
        return
    }

    let nodeManagedObjectID = node.objectID
    let nodeIdentifier = await moc.perform {
        (moc.object(with: nodeManagedObjectID) as? Node)?.identifierWithinManagedObjectContext
    }

    do {
        try await attempt()
    } catch let outOfSyncError where outOfSyncError.isDriveItemOutOfSync {
        Log.warning("Operation failed with out of sync error",
                    domain: .syncing, sendToSentryIfPossible: true)
        guard let nodeIdentifier else { throw outOfSyncError }
        do {
            try await metadataRefresher(nodeIdentifier, moc)
        } catch {
            throw outOfSyncError
        }
        let nodeStillExists = await moc.perform {
            guard let object = try? moc.existingObject(with: nodeManagedObjectID) else { return false }
            return !object.isDeleted
        }
        guard nodeStillExists else { throw OutOfSyncRecoveryError.nodeRemoved }
        guard try await stillNeeded() else { return }
        try await attempt()
    }
}
