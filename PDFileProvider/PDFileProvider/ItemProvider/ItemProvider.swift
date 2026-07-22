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
import FileProvider
import PDClient
import PDCore
import CoreData
import ProtonCoreNetworking

public final class ItemProvider {
    private let decryptor = RevisionDecryptor()

    #if os(macOS)
    private let metadataBatcherLock = NSLock()
    private var metadataBatcher: RequestBatcher<String, String, Void>?
    #endif

    public init() { }

    /// Triggers fetching an item's metadata and returns a Progress object.
    @discardableResult
    public func itemProgress(
        for identifier: NSFileProviderItemIdentifier,
        creatorAddresses: Set<String>,
        fileSystemSlot: FileSystemSlot,
        cloudSlot: any CloudSlotProtocol,
        pool: AsyncManagedObjectContextPool,
        featureFlags: FeatureFlagsRepository? = nil,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        let task = Task { [weak self] in
            guard !Task.isCancelled else { return }
            let itemOrError = await self?.localOrRemoteItem(
                for: identifier,
                creatorAddresses: creatorAddresses,
                fileSystemSlot: fileSystemSlot,
                cloudSlot: cloudSlot,
                pool: pool,
                featureFlags: featureFlags
            )
            guard let itemOrError else { return }
            guard !Task.isCancelled else { return }
            switch itemOrError {
            case .success(let item):
                completionHandler(item, nil)
            
            case .failure(let error):
                // According to comment in NSFileProviderReplicatedExtension.h, if this method return any other error than:
                // * NSFileProviderErrorNoSuchItem (will not be retried)
                // * NSFileProviderErrorNotAuthenticated (will be retried with a back-off)
                // * NSFileProviderErrorServerUnreachable (will be retried with a back-off)
                // than the call will be retried by the system immediately, possibly causing a retry loop.
                // This is why we ensure that only one of these three is returned here.
                let mappedError = PDFileProvider.Errors.mapLegacyErrorToFileProviderError(error)
                switch mappedError {
                case let fpError as NSFileProviderError
                    where fpError.code == .notAuthenticated || fpError.code == .noSuchItem || fpError.code == .serverUnreachable:
                    completionHandler(nil, fpError)
                
                case let fpError as NSFileProviderError
                    where fpError.code == .syncAnchorExpired || fpError.code == .pageExpired || fpError.code == .excludedFromSync:
                    let noSuchItemError = NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier)
                    completionHandler(nil, noSuchItemError)
                    
                default:
                    let serverUnreachableError = NSFileProviderError.create(.serverUnreachable, from: error)
                    completionHandler(nil, serverUnreachableError)
                }
            }
        }
        return Progress { _ in
            Log.info("Item for identifier cancelled", domain: .fileProvider)
            task.cancel()
            completionHandler(nil, CocoaError(.userCancelled))
        }
    }
    
    /// Synchronously returns a local item (or error, if item was not found locally).
    /// Creator is relevant only for root folder.
    public func localItem(
        for identifier: NSFileProviderItemIdentifier,
        creatorAddresses: Set<String>,
        fileSystemSlot: FileSystemSlot,
        moc: NSManagedObjectContext
    ) -> Result<NSFileProviderItem, Errors> {
        switch identifier {
        case .rootContainer:
            guard !creatorAddresses.isEmpty, let mainShare = fileSystemSlot.getMainShare(of: creatorAddresses, moc: moc), let root = moc.performAndWait({ mainShare.root }) else {
                Log.error(error: Errors.noMainShare, domain: .fileProvider)
                return .failure(Errors.noMainShare)
            }
            Log.info("Got item ROOT", domain: .fileProvider)
            do {
                let item = try NodeItem(node: root)
                return .success(item)
            } catch {
                return .failure(Errors.itemCannotBeCreated)
            }

        case .workingSet:
            Log.info("Getting item WORKING_SET does not make sense", domain: .fileProvider)
            return .failure(Errors.requestedItemForWorkingSet(identifier: identifier))
            
        case .trashContainer:
            Log.info("Getting item TRASH does not make sense", domain: .fileProvider)
            return .failure(Errors.requestedItemForTrash(identifier: identifier))

        default:
            guard let nodeId = NodeIdentifier(identifier) else {
                let rawItemId = identifier.rawValue

                Log.error(
                    error: Errors.nodeIdentifierNotFound(identifier: identifier),
                    domain: .fileProvider,
                    context: LogContext("len: \(rawItemId.count), slashes: \(rawItemId.filter { $0 == "/" }.count)")
                )

                return .failure(Errors.nodeIdentifierNotFound(identifier: identifier))
            }
            guard let node = fileSystemSlot.getNode(nodeId, moc: moc) else {
                Log.error(error: Errors.nodeNotFound(identifier: identifier), domain: .fileProvider)
                return .failure(Errors.nodeNotFound(identifier: identifier))
            }
            let (nodeState, isTrashInheriting) = moc.performAndWait { (node.state, node.isTrashInheriting) }
            guard nodeState != .deleted, !isTrashInheriting else {
                // We don't want trashed items to display locally (disassociated items are
                // no longer managed by the File Provider and so don't get asked for)
                return .failure(Errors.nodeFoundInTrash(identifier: identifier))
            }
            do {
                let item = try NodeItem(node: node)
                Log.debug("Got item \(~item)", domain: .fileProvider)
                return .success(item)
            } catch {
                return .failure(Errors.itemCannotBeCreated)
            }
        }
    }

    /// Returns a local item if available, otherwise fetches it remotely.
    /// Creator is relevant only for root folder.
    private func localOrRemoteItem(
        for identifier: NSFileProviderItemIdentifier,
        creatorAddresses: Set<String>,
        fileSystemSlot: FileSystemSlot,
        cloudSlot: any CloudSlotProtocol,
        pool: AsyncManagedObjectContextPool,
        featureFlags: FeatureFlagsRepository?
    ) async -> Result<NSFileProviderItem, Error> {
        let localItemOrError = await pool.withContext { moc in
            self.localItem(for: identifier, creatorAddresses: creatorAddresses, fileSystemSlot: fileSystemSlot, moc: moc)
        }

        // ...if item was found, don't try remote — we have metadata...
        if case .success = localItemOrError {
            return localItemOrError.mapError { $0 }
        }

        // ...if the error is other than nodeNotFound, which indicates we don't have node in our database, there is no point in calling remote...
        guard case .failure(.nodeNotFound) = localItemOrError else {
            return localItemOrError.mapError { $0 }
        }

        // ...if error is nodeNotFound, try remote.
        guard let nodeId = NodeIdentifier(identifier) else {
            let rawItemId = identifier.rawValue

            Log.error(
                error: Errors.nodeIdentifierNotFound(identifier: identifier),
                domain: .fileProvider,
                context: LogContext("len: \(rawItemId.count), slashes: \(rawItemId.filter { $0 == "/" }.count)")
            )

            return .failure(Errors.nodeIdentifierNotFound(identifier: identifier))
        }

        do {
            #if os(macOS)
            let batchingDisabled = featureFlags?.isEnabled(flag: .driveMacFileProviderBatchingDisabled) ?? false
            if !batchingDisabled {
                try await enqueueInBatch(
                    nodeId: nodeId, cloudSlot: cloudSlot, pool: pool, featureFlags: featureFlags
                )
            }
            #endif

            return try await pool.withContext { moc in
                let remoteNode: Node
                #if os(macOS)
                if batchingDisabled {
                    remoteNode = try await cloudSlot.scanNode(nodeId, linkProcessingErrorTransformer: { $1 }, moc: moc)
                } else {
                    // Batched flush already persisted; refetch in this moc.
                    guard let refetched = fileSystemSlot.getNode(nodeId, moc: moc) else {
                        return .failure(Errors.nodeNotFound(identifier: identifier))
                    }
                    remoteNode = refetched
                }
                #else
                remoteNode = try await cloudSlot.scanNode(nodeId, linkProcessingErrorTransformer: { $1 }, moc: moc)
                #endif

                let (remoteNodeState, remoteNodeIsTrashInheriting) = moc.performAndWait {
                    (remoteNode.state, remoteNode.isTrashInheriting)
                }

                guard remoteNodeState != .deleted, !remoteNodeIsTrashInheriting else {
                    // We don't want trashed items to display locally (disassociated items are
                    // no longer managed by the File Provider and so don't get asked for)
                    return .failure(Errors.nodeFoundInTrash(identifier: identifier))
                }
                do {
                    let item = try NodeItem(node: remoteNode)
                    Log.debug("Got item \(~item)", domain: .fileProvider)
                    return .success(item)
                } catch {
                    return .failure(Errors.itemCannotBeCreated)
                }
            }
        } catch let error as RequestBatcherError where error == .idNotInResponse {
            // Backend response didn't include this link — treat as not found.
            return .failure(Errors.nodeNotFound(identifier: identifier))
        } catch {
            if let responseError = error as? ResponseError,
               responseError.responseCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue {
                return .failure(Errors.nodeNotFound(identifier: identifier))
            } else {
                return .failure(error)
            }
        }
    }
}

#if os(macOS)
extension ItemProvider {
    
    private func enqueueInBatch(
        nodeId: NodeIdentifier,
        cloudSlot: any CloudSlotProtocol,
        pool: AsyncManagedObjectContextPool,
        featureFlags: FeatureFlagsRepository?
    ) async throws {
        // Lock-protected so concurrent first-time access can't construct two batchers.
        let metadataBatcher: RequestBatcher<String, String, Void> = metadataBatcherLock.withLock {
            if let metadataBatcher = self.metadataBatcher {
                return metadataBatcher
            }
            let metadataBatcher = RequestBatcher<String, String, Void>(
                maxBatchSize: CloudSlot.maxBatchSize,
                maxLatency: .seconds(5)
            ) { [weak cloudSlot, weak pool, featureFlags] linkIDs, shareID in
                await Self.flushMetadataBatch(
                    linkIDs: linkIDs,
                    shareID: shareID,
                    cloudSlot: cloudSlot as? CloudSlot,
                    pool: pool,
                    featureFlags: featureFlags
                )
            }
            self.metadataBatcher = metadataBatcher
            return metadataBatcher
        }

        let linkID = nodeId.nodeID
        let shareID = nodeId.shareID
        // Don't hold a moc during the enqueue wait — the flush acquires its own.
        try await withTaskCancellationHandler {
            try await metadataBatcher.enqueue(item: linkID, key: shareID, id: linkID)
        } onCancel: {
            Task { await metadataBatcher.cancel(id: linkID, key: shareID) }
        }
    }

    private static func flushMetadataBatch(
        linkIDs: [String],
        shareID: String,
        cloudSlot: CloudSlot?,
        pool: AsyncManagedObjectContextPool?,
        featureFlags: FeatureFlagsRepository?
    ) async -> [String: Result<Void, Error>] {
        guard let cloudSlot, let pool else {
            Log.error("Metadata batch flush dropped — cloudSlot or pool deallocated", domain: .fileProvider)
            return Dictionary(uniqueKeysWithValues: linkIDs.map {
                ($0, .failure(NSFileProviderError(.serverUnreachable)))
            })
        }

        // If the kill switch was flipped while items waited, drain via legacy per-item.
        if featureFlags?.isEnabled(flag: .driveMacFileProviderBatchingDisabled) ?? false {
            return await flushMetadataBatchOneAtATime(shareID, linkIDs, pool, cloudSlot)
        }

        Log.info(
            "Flushing metadata batch (share=\(shareID), \(linkIDs.count) links)",
            domain: .fileProvider
        )
        do {
            try await pool.withContext { moc in
                try await cloudSlot.scanNodes(linkIDs: linkIDs, shareID: shareID, moc: moc)
            }
            return Dictionary(uniqueKeysWithValues: linkIDs.map { ($0, .success(())) })
        } catch {
            Log.error("Metadata batch flush failed", error: error, domain: .fileProvider)
            return Dictionary(uniqueKeysWithValues: linkIDs.map { ($0, .failure(error)) })
        }
    }
    
    private static func flushMetadataBatchOneAtATime(_ shareID: String, _ linkIDs: [String], _ pool: AsyncManagedObjectContextPool, _ cloudSlot: CloudSlot) async -> [String: Result<Void, any Error>] {
        Log.info(
            "Metadata batch flush degrading to legacy per-item (share=\(shareID), \(linkIDs.count) links)",
            domain: .fileProvider
        )
        return await pool.withContext { moc in
            await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
                for linkID in linkIDs {
                    group.addTask {
                        let nodeId = NodeIdentifier(linkID, shareID, "")
                        do {
                            _ = try await cloudSlot.scanNode(nodeId, linkProcessingErrorTransformer: { $1 }, moc: moc)
                            return (linkID, .success(()))
                        } catch {
                            return (linkID, .failure(error))
                        }
                    }
                }
                var results: [String: Result<Void, Error>] = [:]
                for await (linkID, result) in group {
                    results[linkID] = result
                }
                return results
            }
        }
    }
}
#endif
