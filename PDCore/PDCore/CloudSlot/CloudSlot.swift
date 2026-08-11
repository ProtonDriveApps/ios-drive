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
import CoreData
import PDClient
import ProtonCoreUtilities

enum UploadedRevisionCheckerError: LocalizedError {
    case revisionNotCommitedFakeNews
    case noXAttrsInActiveRevision
    case xAttrsDoNotMatch
    case blockUploadEmpty
    case blockUploadSizeIncorrect
    case blockUploadCountIncorrect

    var errorDescription: String? {
        switch self {
        case .revisionNotCommitedFakeNews:
            return "Revision not finalized"
        case .noXAttrsInActiveRevision:
            return "Missing XAttrs in active revision"
        case .xAttrsDoNotMatch:
            return "XAttrs don't match those uploaded"
        case .blockUploadEmpty:
            return "Some file parts were empty"
        case .blockUploadSizeIncorrect:
            return "Some file parts did not match their expected sizes"
        case .blockUploadCountIncorrect:
            return "Some file parts failed to upload"
        }
    }
}

public enum CloudSlotErrors: LocalizedError, CaseIterable {
    case noSharesAvailable
    case noRevisionCreated
    case noNamesApproved
    case noNodeFound
    case failedToFindBlockKey
    case failedToFindBlockSignature
    case failedToFindBlockHash
    case failedToEncryptBlocks
    case couldNotFindMainShareForNewShareCreation
    case couldNotFindVolumeForNewShareCreation

    public var errorDescription: String? {
        switch self {
        case .noSharesAvailable: return "This account has no shares"
        case .noRevisionCreated: return "No file revisions created"
        case .noNamesApproved: return "None of file names is allowed"
        case .noNodeFound: return "Node not found"
        case .failedToEncryptBlocks, .failedToFindBlockKey, .failedToFindBlockHash, .failedToFindBlockSignature: return "Failed to encrypt block"
        case .couldNotFindMainShareForNewShareCreation:
            return "Failed to share node that is not part of Volume"
        case .couldNotFindVolumeForNewShareCreation:
            return "Failed to share node because could not find Volume"
        }
    }
}

enum CloudFileCleanerError: Error {
    case fileIsNotADraft
}

public enum CloudScanError: Error {
    /// `scanNodes` ancestor resolution did not converge within the depth cap.
    case ancestorResolutionDepthExceeded(unresolved: Set<String>)
}

public typealias ShareShortMeta = PDClient.ShareShort
public typealias ShareMeta = PDClient.Share
public typealias ShareObj = PDCore.Share
public typealias VolumeMeta = PDClient.Volume
public typealias VolumeObj = PDCore.Volume
public typealias RevisionMeta = PDClient.Revision
public typealias RevisionObj = PDCore.Revision

public typealias LinkMeta = PDClient.Link
public typealias NodeObj = PDCore.Node
public typealias FolderObj = PDCore.Folder
public typealias FileObj = PDCore.File
public typealias PhotoObj = PDCore.Photo
public typealias BlockMeta = PDClient.Block
public typealias BlockObj = PDCore.Block

public typealias ShareURLMeta = PDClient.ShareURLMeta
public typealias NoShare = Void

public typealias XAttrs = String

public typealias AvailableHashCheckerCompletion = (Result<[String], Error>) -> Void

public class CloudSlot: CloudSlotProtocol {
    public typealias Errors = CloudSlotErrors

    /// Hard cap on `scanNodes` ancestor-resolution iterations.
    @usableFromInline static let ancestorResolutionDepthCap = 900
    
    public static let maxBatchSize = 150

    private let storage: StorageManager
    private let client: Client
    private let sessionVault: SessionVault

    private let completionQueue = DispatchQueue.global(qos: .default)

    private let instanceIdentifier = UUID()
    private let parentIDFetcher: NodeParentIDFetcher
    
    public var backgroundContext: NSManagedObjectContext {
        storage.backgroundContext
    }

    public init(client: Client, storage: StorageManager, sessionVault: SessionVault, parentIDFetcher: NodeParentIDFetcher) {
        self.client = client
        self.storage = storage
        self.sessionVault = sessionVault
        self.parentIDFetcher = parentIDFetcher
        Log.info("CloudSlot init: \(instanceIdentifier)", domain: .syncing)
    }

    deinit {
        Log.info("CloudSlot deinit: \(instanceIdentifier)", domain: .syncing)
    }

    private var signersKitFactory: SignersKitFactoryProtocol {
        sessionVault
    }

    private func makeSupportedSharesValidator() -> SupportedSharesValidator {
        #if os(iOS)
        return iOSSupportedSharesValidator(storage: storage)
        #else
        return macOSSupportedSharesValidator()
        #endif
    }
}

public protocol CloudSlotProtocol: AnyObject,
    CloudShareScannerProtocol,
    CloudRootScannerProtocol,
    CloudShareAndRootFolderScannerProtocol,
    CloudTrashScannerProtocol,
    CloudChildrenScannerProtocol,
    CloudNodeScannerProtocol,
    CloudRevisionScannerProtocol,
    CloudFileCleaner,
    FolderCreatorProtocol,
    NodeRenamerProtocol,
    CloudNodeMoverProtocol,
    CloudEventProvider,
    ThumbnailCloudClient,
    CloudAsyncVolumeCreatorProtocol,
    CloudUpdaterProtocol,
    CloudTrasherProtocol,
    ThumbnailsUpdateRepository
{
}

public protocol CloudShareScannerProtocol {
    func scanShare(shareID: String, moc: NSManagedObjectContext, handler: @escaping (Result<Share, Error>) -> Void)
}

public protocol CloudRootScannerProtocol {
    func scanRoots(isPhotosEnabled: Bool, moc: NSManagedObjectContext, onFoundMainShare: @escaping (Result<Share, Error>) -> Void, onMainShareNotFound: @escaping () -> Void)
    func scanRootsAsync(isPhotosEnabled: Bool, moc: NSManagedObjectContext) async throws -> Share?
}

public protocol CloudShareAndRootFolderScannerProtocol {
    func scanShareAndRootFolder(shareID: String, moc: NSManagedObjectContext, handler: @escaping (Result<Share, Error>) -> Void)
}

public protocol CloudTrashScannerProtocol {
    func scanAllTrashed(volumeID: String, moc: NSManagedObjectContext) async throws
}

public protocol CloudChildrenScannerProtocol {
    func scanChildren(of parentID: NodeIdentifier, parameters: [FolderChildrenEndpointParameters]?, moc: NSManagedObjectContext, handler: @escaping (Result<[Node], Error>) -> Void)
    func scanChildren(of parentID: NodeIdentifier, parameters: [FolderChildrenEndpointParameters]?, moc: NSManagedObjectContext) async throws -> [Node]
}

public protocol CloudNodeScannerProtocol {
    func scanNode(_ nodeID: NodeIdentifier, linkProcessingErrorTransformer: @escaping (Link, Error) -> Error, moc: NSManagedObjectContext, handler: @escaping (Result<Node, Error>) -> Void)

    func scanNode(_ nodeID: NodeIdentifier, linkProcessingErrorTransformer: @escaping (Link, Error) -> Error, moc: NSManagedObjectContext) async throws -> Node
}

public protocol CloudRevisionScannerProtocol {
#if os(iOS)
    func scanRevision(_ revisionID: RevisionIdentifier, moc: NSManagedObjectContext, handler: @escaping (Result<Revision, Error>) -> Void)
#endif
    func scanRevision(_ revisionID: RevisionIdentifier, moc: NSManagedObjectContext) async throws -> Revision
}

public protocol CloudFileCleaner {
    func deleteUploadingFile(linkId: String, parentId: String, shareId: String, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteUploadingFile(shareId: String, parentId: String, linkId: String) async throws
}

public protocol FolderCreatorProtocol {
    func createFolder(_ name: String, parent: Folder, moc: NSManagedObjectContext) async throws -> Folder
}

public protocol NodeRenamerProtocol {
    func rename(_ node: Node, to newName: String, mimeType: String?, moc: NSManagedObjectContext) async throws
}

public protocol CloudNodeMoverProtocol {
    func move(node: Node, to newParent: Folder, name: String, moc: NSManagedObjectContext) async throws
}

public protocol CloudEventProvider {
    func fetchInitialEvent(ofVolumeID volumeID: String) async throws -> EventID
    func scanEventsFromRemote(ofVolumeID volumeID: String, since loopEventID: EventID) async throws -> EventsEndpoint.Response
}

public protocol CloudPublicLinkProtocol {
    func getSRPModulus(completion: @escaping (Result<Modulus, Error>) -> Void)
    func createShareURL(shareID: ShareMeta.ShareID, parameters: NewShareURLParameters, completion: @escaping (Result<ShareURLMeta, Error>) -> Void)
    func updateShareURL<Parameters: EditShareURLParameters>(shareURLID: ShareURLMeta.ID, shareID: ShareMeta.ShareID, parameters: Parameters, completion: @escaping (Result<ShareURLMeta, Error>) -> Void)
    func deleteShareURL(_ shareURL: ShareURL, completion: @escaping (Result<Void, Error>) -> Void)
}

public protocol CloudAsyncVolumeCreatorProtocol {
    func createVolumeAsync(signersKit: SignersKit, moc: NSManagedObjectContext) async throws -> Share
}

public protocol ThumbnailCloudClient {
    func downloadThumbnailURL(parameters: RevisionThumbnailParameters, completion: @escaping (Result<URL, Error>) -> Void)
}

extension CloudSlot {
    private func updateShare(shareMeta: ShareMeta,
                             moc: NSManagedObjectContext,
                             handler: @escaping (Result<Share, Error>) -> Void) {
        moc.performAndWait {
            let updatedShare = self.update(shareMeta, in: moc)
            do {
                try moc.saveOrRollback()
                handler(.success(updatedShare))
            } catch {
                return handler(.failure(error))
            }
        }
    }

    public func scanShare(shareID: String,
                          moc: NSManagedObjectContext,
                          handler: @escaping (Result<Share, Error>) -> Void) {
        self.client.getShare(shareID) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let shareMeta):
                self.updateShare(shareMeta: shareMeta, moc: moc, handler: handler)
            }
        }
    }

    public func scanRoots(isPhotosEnabled: Bool = false,
                          moc: NSManagedObjectContext,
                          onFoundMainShare: @escaping (Result<Share, Error>) -> Void,
                          onMainShareNotFound: @escaping () -> Void) {
        Task {
            do {
                guard let mainShare = try await scanRootsAsync(moc: moc) else {
                    onMainShareNotFound()
                    return
                }
                await MainActor.run {
                    onFoundMainShare(.success(mainShare))
                }
            } catch {
                await MainActor.run {
                    onFoundMainShare(.failure(error))
                }
            }
        }
    }

    public func scanRootsAsync(isPhotosEnabled: Bool = false,
                               moc: NSManagedObjectContext) async throws -> Share? {
        // we cannot rely on volume state being properly updated before we call for shares first.
        // call for shares updates the volume state as a hidden side effect. this is a BE quirk.
        _ = try await client.getShares()

        let volumes = try await client.getVolumes()

        guard let volume = volumes.first(where: { $0.state == .active }) else {
            return nil
        }

        update(volumes, in: moc)

        let mainShare = try await scanRootShare(volume.share.shareID, moc: moc)
        if isPhotosEnabled {
            do {
                let photosShare = try await client.listPhotoShares()
                _ = try await scanRootShare(photosShare.shareID, moc: moc)
            } catch { }
        }

        return mainShare
    }

    private func scanRootShare(_ shareID: String,
                               moc: NSManagedObjectContext) async throws -> Share {
        try await withCheckedThrowingContinuation { continuation in
            scanShareAndRootFolder(shareID: shareID, moc: moc, handler: continuation.resume(with:))
        }
    }

    public func scanShareAndRootFolder(shareID: String,
                                       moc: NSManagedObjectContext,
                                       handler: @escaping (Result<Share, Error>) -> Void) {
        self.client.getShare(shareID) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let shareMeta):
                let rootNodeIdentifier = NodeIdentifier(shareMeta.linkID, shareMeta.shareID, shareMeta.volumeID)
                self.scanNode(rootNodeIdentifier, moc: moc) { result in
                    switch result {
                    case .failure(let error): handler(.failure(error))
                    case .success: self.updateShare(shareMeta: shareMeta, moc: moc, handler: handler)
                    }
                }
            }
        }
    }

    public func scanAllTrashed(volumeID: String, moc: NSManagedObjectContext) async throws {
        try await fetchTrash(volumeID, atPage: 0, moc: moc)
    }

    private func fetchTrash(_ volumeID: String, atPage page: Int, moc: NSManagedObjectContext) async throws {
        let pageSize = Constants.pageSizeForChildrenFetchAndEnumeration
        do {
            let response = try await client.listVolumeTrash(volumeID: volumeID, page: page, pageSize: pageSize)
            let supportedSharesValidator = makeSupportedSharesValidator()

            for batch in response.trash {
                guard supportedSharesValidator.isValid(batch.shareID),
                      !batch.linkIDs.isEmpty else {
                    continue
                }

                do {
                    let linksResponse = try await client.getLinksMetadata(with: .init(shareId: batch.shareID, linkIds: batch.linkIDs))
                    try await moc.perform { [weak self] in
                        guard let self else { return }
                        _ = try self.update(links: linksResponse.sortedLinks, shareId: batch.shareID, managedObjectContext: moc)
                        try moc.saveOrRollback()
                    }
                } catch {
                    throw error
                }
            }

            guard !response.trash.isEmpty else { return }
            try await fetchTrash(volumeID, atPage: page + 1, moc: moc)
        } catch {
            throw error
        }
    }

    public func scanChildren(of parentID: NodeIdentifier,
                             parameters: [FolderChildrenEndpointParameters]? = nil,
                             moc: NSManagedObjectContext,
                             handler: @escaping (Result<[Node], Error>) -> Void)
    {
        let mode: UpdateMode = (parameters?.containsPagination() ?? false) ? .append : .replace
        self.client.getFolderChildren(parentID.shareID, folderID: parentID.nodeID, parameters: parameters) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let childrenLinksMeta):
                moc.performAndWait {
                    let childrenLinksMetaWithoutDrafts = childrenLinksMeta.filter { $0.state != .draft }
                    let objs = self.update(childrenLinksMetaWithoutDrafts, under: parentID.nodeID, of: parentID.shareID, mode: mode, in: moc)
                    do {
                        try moc.saveOrRollback()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(objs))
                }
            }
        }
    }

    public func scanChildren(of parentID: NodeIdentifier,
                             parameters: [FolderChildrenEndpointParameters]?,
                             moc: NSManagedObjectContext) async throws -> [Node] {
        let mode: UpdateMode = (parameters?.containsPagination() ?? false) ? .append : .replace
        let childrenLinksMeta = try await client.getFolderChildren(
            parentID.shareID,
            folderID: parentID.nodeID,
            parameters: parameters
        )
        return try await moc.perform { [weak self] in
            guard let self else { return [] }
            let childrenLinksMetaWithoutDrafts = childrenLinksMeta.filter { $0.state != .draft }
            let objs = self.update(
                childrenLinksMetaWithoutDrafts,
                under: parentID.nodeID,
                of: parentID.shareID,
                mode: mode,
                in: moc
            )
            try moc.saveOrRollback()
            return objs
        }
    }

    public func scanNode(_ nodeID: NodeIdentifier,
                         linkProcessingErrorTransformer: @escaping (Link, Error) -> Error = { $1 },
                         moc: NSManagedObjectContext,
                         handler: @escaping (Result<Node, Error>) -> Void)
    {
        self.client.getNode(nodeID.shareID, nodeID: nodeID.nodeID, breadcrumbs: .startCollecting()) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let linkMeta):
                moc.performAndWait {
                    let objs = self.update([linkMeta], of: nodeID.shareID, in: moc)
                    do {
                        try moc.saveOrRollback()
                    } catch let error {
                        moc.rollback()
                        return handler(.failure(linkProcessingErrorTransformer(linkMeta, error)))
                    }
                    handler(.success(objs.first!))
                }
            }
        }
    }

    public func scanNode(
        _ nodeID: NodeIdentifier,
        linkProcessingErrorTransformer: @escaping (PDClient.Link, any Error) -> any Error,
        moc: NSManagedObjectContext
    ) async throws -> Node {
        try await withCheckedThrowingContinuation { continuation in
            scanNode(nodeID,
                     linkProcessingErrorTransformer: linkProcessingErrorTransformer,
                     moc: moc,
                     handler: continuation.resume(with:))
        }
    }

    /// Phase 1 output: links accumulated across batched fetches, plus IDs the
    /// backend didn't return.
    private typealias AncestorResolution = (fetchedLinks: [PDClient.Link], deletedIDs: Set<String>)

    /// Batched share-scoped metadata fetch with recursive ancestor resolution.
    ///
    /// Any requested ID the backend doesn't return is treated as deleted; its
    /// subtree is removed before persisting. Persistence happens **once**, at
    /// the end — `update` creates stub Core Data objects for any parent absent
    /// from its input, and saving a stub mid-resolution fails validation.
    public func scanNodes(
        linkIDs: [String],
        shareID: String,
        moc: NSManagedObjectContext,
        maxDepth: Int = CloudSlot.ancestorResolutionDepthCap
    ) async throws {
        let resolution = try await resolveLinksAndAncestors(
            seedLinkIDs: linkIDs, shareID: shareID, maxDepth: maxDepth, moc: moc
        )
        try await persistResolutionWithCascadingDelete(
            resolution, shareID: shareID, moc: moc
        )
    }

    /// Phase 1 — parent-chain traversal. Each iteration fires a batched
    /// metadata request (chunked by the BE 150-link cap) for everything still
    /// unresolved at the current level.
    private func resolveLinksAndAncestors(
        seedLinkIDs: [String],
        shareID: String,
        maxDepth: Int,
        moc: NSManagedObjectContext
    ) async throws -> AncestorResolution {
        var fetchedLinks: [PDClient.Link] = []
        var fetchedIDs = Set<String>()
        var pending = Set(seedLinkIDs)
        var requestCounter = 0
        var deletedIDs = Set<String>()

        while !pending.isEmpty {
            guard requestCounter < maxDepth else {
                throw CloudScanError.ancestorResolutionDepthExceeded(unresolved: pending)
            }
            requestCounter += 1

            let currentBatch = Array(pending)
            pending.removeAll()

            var returnedLinks: [PDClient.Link] = []
            for chunk in currentBatch.splitInGroups(of: CloudSlot.maxBatchSize) {
                let response = try await client.getLinksMetadata(
                    with: LinksMetadataParameters(shareId: shareID, linkIds: chunk)
                )
                returnedLinks.append(contentsOf: response.sortedLinks)
            }
            let returnedIDs = Set(returnedLinks.map(\.linkID))

            // Asked for, didn't come back → deleted on the backend.
            deletedIDs.formUnion(Set(currentBatch).subtracting(returnedIDs))

            let newLinks = returnedLinks.filter { !fetchedIDs.contains($0.linkID) }
            fetchedLinks.append(contentsOf: newLinks)
            fetchedIDs.formUnion(newLinks.map(\.linkID))

            let unresolvedParentIDs = Set(returnedLinks.compactMap(\.parentLinkID))
                .subtracting(fetchedIDs)
                .subtracting(deletedIDs)
            guard !unresolvedParentIDs.isEmpty else { break }

            // Already in DB → `update(_:of:in:)` resolves them via
            // `storage.unique(with:)`, no refetch needed.
            let parentIdentifiers = unresolvedParentIDs.map { NodeIdentifier($0, shareID, "") }
            let parentsAlreadyInDB = moc.performAndWait {
                Set(self.storage.fetchNodes(identifiers: parentIdentifiers, moc: moc).map(\.id))
            }
            pending = unresolvedParentIDs.subtracting(parentsAlreadyInDB)
        }

        return (fetchedLinks: fetchedLinks, deletedIDs: deletedIDs)
    }

    /// Phase 2 — descendant traversal of every deleted ID.
    /// Persists clean links and hard-deletes DB
    /// nodes in the deleted subtree, in a single save.
    private func persistResolutionWithCascadingDelete(
        _ resolution: AncestorResolution,
        shareID: String,
        moc: NSManagedObjectContext
    ) async throws {
        // Seeds may already be in the DB (caller asked for a known ID the
        // backend says is gone) — seed `dbNodesToHardDelete` from them
        // before traversing descendants.
        var idsInDeletedSubtree = resolution.deletedIDs
        let seedIdentifiers = resolution.deletedIDs.map { NodeIdentifier($0, shareID, "") }
        var dbNodesToHardDelete = self.storage.fetchNodes(identifiers: seedIdentifiers, moc: moc)
        var cascadeQueue = Array(resolution.deletedIDs)
        // Precomputed once: walking `fetchedLinks` per cascade id would be O(N×M).
        let linksByParent = Dictionary(grouping: resolution.fetchedLinks) { $0.parentLinkID ?? "" }

        try await moc.perform {
            // Index-based dequeue keeps the cascade O(N); `removeFirst()` is O(N) per pop.
            var head = 0
            while head < cascadeQueue.count {
                let id = cascadeQueue[head]
                head += 1

                // A `fetchedLinks` entry here has no DB equivalent.
                // Excluding it from `cleanLinks` is enough; no DB delete needed.
                // `parentsAlreadyInDB` would have suppressed the parent fetch
                // if the ancestor were already in DB.
                for link in linksByParent[id, default: []]
                    where !idsInDeletedSubtree.contains(link.linkID) {
                    idsInDeletedSubtree.insert(link.linkID)
                    cascadeQueue.append(link.linkID)
                }

                let dbChildren = try self.storage.fetchChildren(
                    of: id, share: shareID, sorting: .default, moc: moc
                )
                for child in dbChildren where !idsInDeletedSubtree.contains(child.id) {
                    idsInDeletedSubtree.insert(child.id)
                    dbNodesToHardDelete.append(child)
                    cascadeQueue.append(child.id)
                }
            }

            let cleanLinks = resolution.fetchedLinks.filter { !idsInDeletedSubtree.contains($0.linkID) }
            self.update(cleanLinks, of: shareID, in: moc)
            for node in dbNodesToHardDelete {
                moc.delete(node)
            }
            try moc.saveOrRollback()
        }
    }

    public func scanRevision(_ revisionID: RevisionIdentifier,
                             moc: NSManagedObjectContext,
                             handler: @escaping (Result<Revision, Error>) -> Void)
    {
        self.client.getRevision(revisionID.shareID, fileID: revisionID.fileID, revisionID: revisionID.revisionID) { result in
            switch result {
            case .failure(let error): handler(.failure(error))
            case .success(let revisionMeta):
                moc.performAndWait {
                    let obj = self.update(revisionMeta, inFileID: revisionID.fileID, of: revisionID.shareID, in: moc)
                    do {
                        try moc.saveOrRollback()
                    } catch let error {
                        return handler(.failure(error))
                    }
                    handler(.success(obj))
                }
            }
        }
    }

    public func scanRevision(_ revisionID: RevisionIdentifier,
                             moc: NSManagedObjectContext) async throws -> Revision {
        let revisionMeta = try await client.getRevision(
            revisionID: revisionID.revisionID,
            fileID: revisionID.fileID,
            shareID: revisionID.shareID
        )
        return try await moc.perform {
            let obj = self.update(revisionMeta, inFileID: revisionID.fileID, of: revisionID.shareID, in: moc)
            try moc.saveOrRollback()
            return obj
        }
    }
}

// MARK: - Delete Uploading files
extension CloudSlot {
    public func deleteUploadingFile(linkId: String, parentId: String, shareId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.deleteNodeInFolder(shareID: shareId, folderID: parentId, nodeIDs: [linkId], completion: completion)
    }

    public func deleteUploadingFile(shareId: String, parentId: String, linkId: String) async throws {
        let link = try await client.getLink(shareID: shareId, linkID: linkId, breadcrumbs: .startCollecting())

        guard link.state == .draft else {
            throw CloudFileCleanerError.fileIsNotADraft
        }

        _ = try await client.deleteChildren(shareID: shareId, folderID: parentId, linkIDs: [linkId])
    }

    private func deleteNodeInFolder(shareID: String, folderID: String, nodeIDs: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        client.deleteLinkInFolderPermanently(shareID: shareID, folderID: folderID, linkIDs: nodeIDs, completion: completion)
    }
}

extension CloudSlot {
    public func createFolder(_ name: String, parent: Folder, moc: NSManagedObjectContext) async throws -> Folder {
        let creator = FolderCreator(cloudFolderCreator: client.createFolder, signersKitFactory: signersKitFactory)

        return try await creator.createFolder(name, parent: parent, moc: moc)
    }

    public func rename(_ node: Node, to newName: String, mimeType: String?, moc: NSManagedObjectContext) async throws {
        let renamer = NodeRenamer(cloudNodeRenamer: client.renameEntry, signersKitFactory: signersKitFactory, metadataRefresher: makeMetadataRefresher())

        return try await renamer.rename(node, to: newName, mimeType: mimeType, moc: moc)
    }

    public func move(node: Node, to newParent: Folder, name: String, moc: NSManagedObjectContext) async throws {
        let mover = NodeMover(cloudNodeMover: client.moveEntry, signersKitFactory: signersKitFactory, parentIDFetcher: parentIDFetcher, metadataRefresher: makeMetadataRefresher())

        return try await mover.move(node, to: newParent, name: name, moc: moc)
    }

    // 2000 ("item out of sync") recovery is macOS-only. On iOS this is nil, so move/rename get no detection, refresh, re-check, or retry.
    // scanNodes resolves the parent chain up to the first folder already in the DB (so a node moved into a
    // locally-unknown folder lands correctly) and removes any node the backend no longer returns.
    private func makeMetadataRefresher() -> NodeMetadataRefreshing? {
        #if os(macOS)
        return { [self] id, moc in
            try await scanNodes(linkIDs: [id.nodeID], shareID: id.shareID, moc: moc)
        }
        #else
        return nil
        #endif
    }

    private func createVolume(signersKit: SignersKit,
                              moc: NSManagedObjectContext,
                              handler: @escaping (Result<Share, Error>) -> Void) {
        let folderName = "root"

        moc.performAndWait {
            do {
                let address = signersKit.address
                let addressKey = signersKit.addressKey
                let share: ShareObj = self.storage.new(with: address.email, by: #keyPath(ShareObj.creator), in: moc)
                let shareKeys = try share.generateShareKeys(signersKit: signersKit)
                share.addressID = address.addressID
                share.key = shareKeys.key
                share.passphrase = shareKeys.passphrase
                share.passphraseSignature = shareKeys.signature

                let root: FolderObj = self.storage.new(with: address.email, by: #keyPath(FolderObj.signatureEmail), in: moc)
                root.directShares.insert(share)

                let rootName = try root.encryptName(cleartext: folderName, signersKit: signersKit)
                root.name = rootName

                let rootKeys = try root.generateNodeKeys(signersKit: signersKit)
                root.nodeKey = rootKeys.key
                root.nodePassphrase = rootKeys.passphrase
                root.nodePassphraseSignature = rootKeys.signature

                let rootHashKey = try root.generateHashKey(nodeKey: rootKeys)
                root.nodeHashKey = rootHashKey

                root.nodeHash = ""
                root.mimeType = ""
                root.signatureEmail = ""
                root.nameSignatureEmail = ""
                root.createdDate = Date()
                root.modifiedDate = Date()

                let parameters = NewVolumeParameters(
                    addressID: address.addressID,
                    addressKeyID: addressKey.keyID,
                    shareKey: shareKeys.key,
                    sharePassphrase: shareKeys.passphrase,
                    sharePassphraseSignature: shareKeys.signature,
                    folderName: rootName,
                    folderKey: rootKeys.key,
                    folderPassphrase: rootKeys.passphrase,
                    folderPassphraseSignature: rootKeys.signature,
                    folderHashKey: rootHashKey
                )

                self.client.postVolume(parameters: parameters) {
                    switch $0 {
                    case .failure(let error):
                        Log.error("CloudSlot postVolume failed", error: DriveError(error), domain: .networking)
                        handler(.failure(error))

                    case .success(let newVolume):
                        moc.performAndWait {
                            share.id = newVolume.share.ID
                            root.id = newVolume.share.linkID
                            root.setShareID(newVolume.share.ID)

                            let volume: VolumeObj = self.storage.new(with: newVolume.ID, by: "id", in: moc)
                            volume.shares.insert(share)

                            handler(.success(share))
                        }
                    }
                }

            } catch {
                Log.error("CloudSlot createVolume failed", error: DriveError(error), domain: .encryption)
                handler(.failure(error))
            }
        }
    }

    public func createVolumeAsync(signersKit: SignersKit, moc: NSManagedObjectContext) async throws -> Share {
        return try await withCheckedThrowingContinuation { continuation in
            createVolume(signersKit: signersKit, moc: moc) { result in
                switch result {
                case .success(let share):
                    continuation.resume(returning: share)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

}

// MARK: - CloudEventProvider
extension CloudSlot {

    public func fetchInitialEvent(ofVolumeID volumeID: String) async throws -> EventID {
        try await withCheckedThrowingContinuation { continuation in
            client.getLatestEvent(volumeID, completion: continuation.resume)
        }
    }

    public func scanEventsFromRemote(ofVolumeID volumeID: String, since loopEventID: EventID) async throws -> EventsEndpoint.Response {
        try await withCheckedThrowingContinuation { continuation in
            client.getEvents(volumeID, since: loopEventID, completion: continuation.resume)
        }
    }
}

// MARK: - ThumbnailCloudClient
extension CloudSlot {
    public func downloadThumbnailURL(parameters: RevisionThumbnailParameters, completion: @escaping (Result<URL, Error>) -> Void) {
        client.getRevisionThumbnailURL(parameters: parameters, completion: completion)
    }
}

// TODO: iOS only delete
public protocol CloudUpdaterProtocol {
    func update(_ links: [LinkMeta], of shareID: ShareMeta.ShareID, in moc: NSManagedObjectContext) -> [NodeObj]
    func update(links: [PDClient.Link], shareId: String, managedObjectContext: NSManagedObjectContext) throws
}

// MARK: - CloudTrasherProtocol
public protocol CloudTrasherProtocol {
    func trash(shareID: Client.ShareID, parentID: Client.LinkID, linkIDs: [Client.LinkID]) async throws
    func trash(_ nodes: [TrashingNodeIdentifier]) async throws
    func trashVolume(nodeIDs: [AnyVolumeIdentifier]) async throws
    func delete(shareID: Client.ShareID, linkIDs: [Client.LinkID]) async throws
    func emptyTrash(shareID: Client.ShareID) async throws
    func restore(shareID: Client.ShareID, linkIDs: [Client.LinkID]) async throws -> [PartialFailure]
    func removeMember(shareID: String, memberID: String) async throws
}

// MARK: - CloudUpdaterProtocol
extension CloudSlot {
    enum UpdateMode {
        case replace, append
    }

    /// Creates or updates Shares. Will create minimal objects for Volumes and Links as side effect, or will update relationships on present ones.
    @discardableResult
    private func update(_ shares: [ShareShortMeta], in moc: NSManagedObjectContext) -> [ShareObj] {
        var result: [ShareObj] = []

        // switch to MOC's thread
        moc.performAndWait {
            // get all affected IDs
            var affectedIds = (
                shares: Set<ShareMeta.ShareID>(),
                files: Set<LinkMeta.LinkID>(),
                folders: Set<LinkMeta.LinkID>(),
                photos: Set<LinkMeta.LinkID>(),
                volumes: Set<VolumeMeta.VolumeID>()
            )

            shares.forEach {
                affectedIds.shares.insert($0.shareID)
                affectedIds.volumes.insert($0.volumeID)
                affectedIds.files.insert($0.linkID)
                affectedIds.photos.insert($0.linkID)
                affectedIds.folders.insert($0.linkID)
            }

            // create minimal objects for them
            let uniqueShares: [ShareObj] = self.storage.unique(with: affectedIds.shares, in: moc)
            let uniqueFiles: [FileObj] = self.storage.existing(with: affectedIds.files, in: moc)
            let uniquePhotos: [PhotoObj] = self.storage.existing(with: affectedIds.photos, allowSubclasses: true, in: moc)
            let uniqueFolders: [FolderObj] = self.storage.existing(with: affectedIds.folders, in: moc)
            let uniqueVolumes: [VolumeObj] = self.storage.unique(with: affectedIds.volumes, in: moc)

            // set up share and relationships
            result = shares.compactMap { shareMeta in
                // root may be either folder or file or photo
                let node = uniqueFolders.first { $0.id == shareMeta.linkID } ?? uniqueFiles.first { $0.id == shareMeta.linkID } ?? uniquePhotos.first { $0.id == shareMeta.linkID }
                let volume = uniqueVolumes.first { $0.id == shareMeta.volumeID }
                let share = uniqueShares.first { $0.id == shareMeta.shareID }

                share?.setValue(node, forKey: #keyPath(ShareObj.root))
                share?.setValue(volume, forKey: #keyPath(ShareObj.volume))
                share?.fulfillShare(with: shareMeta)

                node?.directShares.insert(share!)
                if shareMeta.flags.contains(.main) {
                    node?.setValue(shareMeta.shareID, forKey: #keyPath(NodeObj.shareID))
                }

                return share
            }
        }

        return result
    }

    // Not part of the interface created just for tests, delete if possible
    @discardableResult
    public func update(_ volumes: [VolumeMeta], in moc: NSManagedObjectContext) -> [VolumeObj] {
        var result: [VolumeObj] = []

        // switch to MOC's thread
        moc.performAndWait {
            // get all affected IDs
            let affectedIds = Set<VolumeMeta.VolumeID>(volumes.map(\.volumeID))

            // create minimal objects for them
            let uniqueVolumes: [VolumeObj] = self.storage.unique(with: affectedIds, in: moc)

            // set up share and relationships
            result = volumes.compactMap { volumeMeta in
                let volume = uniqueVolumes.first { $0.id == volumeMeta.volumeID }
                volume?.fulfillVolume(with: volumeMeta)
                return volume
            }
        }

        return result
    }

    // Not part of the interface created just for tests, delete if possible
    @discardableResult
    public func update(_ shares: [ShareMeta], in moc: NSManagedObjectContext) -> [ShareObj] {
        let result: [ShareObj] = self.update(shares.map(ShareShortMeta.init), in: moc)
        zip(result, shares).forEach { $0.fulfillShare(with: $1) }
        return result
    }

    @discardableResult
    private func update(_ share: ShareMeta, in moc: NSManagedObjectContext) -> ShareObj {
        return update([share], in: moc).first!
    }

    @discardableResult
    public func update(_ links: [LinkMeta], of shareID: ShareMeta.ShareID, in moc: NSManagedObjectContext) -> [NodeObj] {
        var result: [NodeObj] = []

        // switch to MOC's thread
        moc.performAndWait {
            // get all affected IDs
            var affectedIds = (
                files: Set<LinkMeta.LinkID>(),
                folders: Set<LinkMeta.LinkID>(),
                revisions: Set<RevisionMeta.RevisionID>(),
                shares: Set<ShareMeta.ShareID>(),
                photos: Set<String>(),
                photoRevisions: Set<String>()
            )
            links.forEach { link in
                if let parent = link.parentLinkID {
                    affectedIds.folders.insert(parent)
                }
                if let shareID = link.sharingDetails?.shareID { affectedIds.shares.insert(shareID) }
                switch link.type {
                case .file:
                    let photo = link.fileProperties?.activeRevision?.photo
                    let isPhoto = photo != nil
                    if isPhoto {
                        affectedIds.photos.insert(link.linkID)
                        affectedIds.photos.formUnion([photo?.mainPhotoLinkID].compactMap { $0 })
                    } else {
                        affectedIds.files.insert(link.linkID)
                    }
                    guard let revision = link.fileProperties?.activeRevision else { return }
                    if isPhoto {
                        affectedIds.photoRevisions.insert(revision.ID)
                    } else {
                        affectedIds.revisions.insert(revision.ID)
                    }

                case .folder:
                    affectedIds.folders.insert(link.linkID)

                case .album:
                    Log.error("Trying to update Album by old update function", error: nil, domain: .metadata)
                    assertionFailure("Shouldn't be used by iOS and Albums feature isn't supported on macOS")
                }
            }

            // create minimal objects for them
            let uniqueFiles: [FileObj] = self.storage.unique(with: Set(affectedIds.files), in: moc)
            let uniqueFolders: [FolderObj] = self.storage.unique(with: Set(affectedIds.folders), in: moc)
            let uniqueRevisions: [RevisionObj] = self.storage.unique(with: Set(affectedIds.revisions), in: moc)
            let uniqueShares: [ShareObj] = self.storage.unique(with: Set(affectedIds.shares), in: moc)
            let uniquePhotos: [Photo] = self.storage.unique(with: Set(affectedIds.photos), in: moc)
            let uniquePhotoRevisions: [PhotoRevision] = self.storage.unique(with: Set(affectedIds.photoRevisions), in: moc)

            // set up share and relationships
            result = links.compactMap { link in
                let nodeObj: NodeObj? = uniqueFiles.first { $0.id == link.linkID } ?? uniqueFolders.first { $0.id == link.linkID } ?? uniquePhotos.first { $0.id == link.linkID }
                let parentLinkObj = uniqueFolders.first { $0.id == link.parentLinkID }
                let directShares = uniqueShares.filter { link.sharingDetails?.shareID == $0.id }
                parentLinkObj?.setValue(shareID, forKey: #keyPath(NodeObj.shareID))

                if let photo = nodeObj as? Photo,
                   let revisionResponse = link.fileProperties?.activeRevision,
                   let localRevision = uniquePhotoRevisions.first(where: { $0.id == revisionResponse.ID })
                {
                    photo.addToRevisions(localRevision)
                    photo.photoRevision = localRevision
                    photo.activeRevision = localRevision
                    localRevision.fulfillRevision(link: link, revision: revisionResponse)

                    if revisionResponse.hasThumbnail, let thumbnails = revisionResponse.thumbnails {
                        addThumbnails(thumbnails, revision: localRevision, in: moc)
                    }
                    if let mainPhotoId = link.fileProperties?.activeRevision?.photo?.mainPhotoLinkID,
                       let mainPhoto = uniquePhotos.first(where: { $0.id == mainPhotoId }) {
                           photo.parent = mainPhoto
                    }
                } else if let fileObj = nodeObj as? FileObj,
                    let revisionResponse = link.fileProperties?.activeRevision,
                    let localRevision = uniqueRevisions.first(where: { $0.id == revisionResponse.ID })
                {
                    fileObj.addToRevisions(localRevision)
                    fileObj.activeRevision = localRevision
                    localRevision.fulfillRevision(with: revisionResponse)

                    if revisionResponse.hasThumbnail, let thumbnails = revisionResponse.thumbnails {
                        addThumbnails(thumbnails, revision: localRevision, in: moc)
                    }
                }
                nodeObj?.setValue(parentLinkObj, forKey: #keyPath(NodeObj.parentLink))
                nodeObj?.setValue(shareID, forKey: #keyPath(NodeObj.shareID))

                #if os(macOS)
                // Important for when enumerating items of a kept downloaded parent
                if let parentLinkObj, parentLinkObj.isAvailableOffline {
                    nodeObj?.setValue(true, forKey: #keyPath(NodeObj.isInheritingOfflineAvailable))
                }
                #endif

                (nodeObj as? FileObj)?.fulfillFile(with: link)
                (nodeObj as? FolderObj)?.fulfillFolder(with: link)
                (nodeObj as? Photo)?.fulfillPhoto(with: link)

                nodeObj?.setValue(link.sharingDetails?.shareUrl != nil, forKey: #keyPath(Node.isShared))

                directShares.forEach { share in
                    share.setValue(nodeObj, forKey: #keyPath(ShareObj.root))
                    nodeObj?.directShares.insert(share)
                }

                return nodeObj
            }
        }

        return result
    }

    private func addThumbnails(_ thumbnails: [PDClient.Thumbnail], revision: Revision, in moc: NSManagedObjectContext) {
        thumbnails.forEach { thumbnail in
            let thumbnailID = thumbnail.thumbnailID
            let thumbnailType: ThumbnailType = thumbnail.type == 1 ? .default : .photos

            let localThumbnail = getLocalThumbnail(id: thumbnailID, type: thumbnailType, hash: thumbnail.hash, revision: revision, moc: moc)
            localThumbnail.id = thumbnailID
            localThumbnail.type = thumbnailType
            localThumbnail.sha256 = Data(base64Encoded: thumbnail.hash)
        }
    }

    private func getLocalThumbnail(id: String, type: ThumbnailType, hash: String, revision: Revision, moc: NSManagedObjectContext) -> Thumbnail {
        let localThumbnailByID = revision.thumbnails.first(where: { $0.id == id })
        let localThumbnailByType = revision.thumbnails.first(where: { $0.type == type })

        if let localThumbnail = localThumbnailByID ?? localThumbnailByType {
            return localThumbnail
        } else {
            return Thumbnail.make(id: id, downloadURL: nil, revision: revision, type: type, hash: hash, in: moc)
        }
    }

    private func updateThumbnails(with urls: [ThumbnailURL], in moc: NSManagedObjectContext) {
        let ids = Set(urls.map(\.id))
        let thumbnails: [Thumbnail] = self.storage.existing(with: ids, in: moc)
        for thumbnail in thumbnails {
            guard let info = urls.first(where: { $0.id == thumbnail.id }) else {
                continue
            }
            guard thumbnail.downloadURL != info.url.absoluteString else {
                continue
            }
            thumbnail.downloadURL = info.url.absoluteString
        }
    }

    @discardableResult
    private func update(_ children: [LinkMeta],
                        under folderID: LinkMeta.LinkID,
                        of shareID: ShareMeta.ShareID,
                        mode: UpdateMode = .replace,
                        in moc: NSManagedObjectContext) -> [NodeObj]
    {
        let children = self.update(children, of: shareID, in: moc)
        var result: [NodeObj] = []

        // switch to MOC's thread
        moc.performAndWait {
            let folderObj: FolderObj = self.storage.unique(with: Set([folderID]), in: moc).first!
            switch mode {
            case .replace:
                folderObj.children = Set(children)
            case .append:
                folderObj.children.formUnion(Set(children))
            }

            result = children
        }

        return result
    }

    @discardableResult
    private func update(_ revision: RevisionMeta,
                        inFileID fileID: LinkMeta.LinkID,
                        of shareID: ShareMeta.ShareID,
                        in moc: NSManagedObjectContext) -> RevisionObj
    {
        var result: RevisionObj!

        // switch to MOC's thread
        moc.performAndWait {
            // set up share and relationships
            let revisionObj: RevisionObj = self.storage.unique(with: Set([revision.ID]), allowSubclasses: true, in: moc).first!
            revisionObj.fulfillRevision(with: revision)

            let fileObj: File = self.storage.unique(with: Set([fileID]), allowSubclasses: true, in: moc).first!
            fileObj.setValue(shareID, forKey: #keyPath(NodeObj.shareID))

            self.storage.removeOutdatedCache(of: revisionObj)

            let newBlocks: [DownloadBlock] = self.storage.unique(with: Set(revision.blocks.map { $0.URL.absoluteString }),
                                                         uniqueBy: #keyPath(DownloadBlock.downloadUrl),
                                                         in: moc)
            newBlocks.forEach { block in
                let meta = revision.blocks.first { $0.URL.absoluteString == block.downloadUrl }!
                block.fulfillBlock(with: meta)
                block.setValue(revisionObj, forKey: #keyPath(BlockObj.revision))
            }

            revisionObj.setValue(fileObj, forKey: #keyPath(RevisionObj.file))
            revisionObj.blocks = Set(newBlocks)
            result = revisionObj
        }

        return result
    }

    @discardableResult
    private func update(_ revisionID: RevisionMeta.RevisionID,
                        inFileID fileID: LinkMeta.LinkID,
                        of shareID: ShareMeta.ShareID,
                        in moc: NSManagedObjectContext) -> RevisionObj
    {
        var result: RevisionObj!

        moc.performAndWait {
            // set up new revision and relationships
            let revisionObj: RevisionObj = self.storage.unique(with: Set([revisionID]), in: moc).first!

            let fileObj: File = self.storage.unique(with: Set([fileID]), in: moc).first!
            fileObj.setValue(shareID, forKey: #keyPath(NodeObj.shareID))

            revisionObj.setValue(fileObj, forKey: #keyPath(RevisionObj.file))
            fileObj.addToRevisions(revisionObj)
            result = revisionObj
        }

        return result
    }

    @discardableResult
    private func update(_ newFileDetails: NewFile, file: FileObj) -> FileObj {
        let moc = file.managedObjectContext!
        moc.performAndWait {
            file.fulfillFile(with: newFileDetails)

            let revision: RevisionObj = self.storage.unique(with: Set([newFileDetails.revisionID]), in: moc).first!
            file.activeRevision = revision
            file.addToRevisions(revision)
        }
        return file
    }

    public func update(links: [PDClient.Link], shareId: String, managedObjectContext: NSManagedObjectContext) throws {
        try managedObjectContext.performAndWait {
            update(links, of: shareId, in: managedObjectContext)
            try managedObjectContext.saveOrRollback()
        }
    }

    public func update(thumbnails: [ThumbnailURL], moc: NSManagedObjectContext) throws {
        try moc.performAndWait {
            updateThumbnails(with: thumbnails, in: moc)
            try moc.saveOrRollback()
        }
    }
}

extension CloudSlot {
    public func trash(_ nodes: [TrashingNodeIdentifier]) async throws  {
        fatalError("Not to be used on legacy CloudSlot")
    }

    public func trash(shareID: Client.ShareID, parentID: Client.LinkID, linkIDs: [Client.LinkID]) async throws {
        try await client.trash(shareID: shareID, parentID: parentID, linkIDs: linkIDs)
    }

    public func trashVolume(nodeIDs: [AnyVolumeIdentifier]) async throws {
        fatalError("Not to be used on legacy CloudSlot")
    }

    public func delete(shareID: Client.ShareID, linkIDs: [Client.LinkID]) async throws {
        try await client.deletePermanently(shareID: shareID, linkIDs: linkIDs)
    }

    public func emptyTrash(shareID: Client.ShareID) async throws {
        try await client.emptyTrash(shareID: shareID)
    }

    public func restore(shareID: Client.ShareID, linkIDs: [Client.LinkID]) async throws -> [PartialFailure] {
        try await client.retoreTrashNode(shareID: shareID, linkIDs: linkIDs)
    }

    public func removeMember(shareID: String, memberID: String) async throws {
        fatalError("Not defined in this context")
    }
}

public struct DeviceIdentifier: VolumeIdentifiable, Equatable {
    public let id: String
    public let nodeID: String
    public let shareID: String
    public let volumeID: String

    public init(id: String, nodeID: String, shareID: String, volumeID: String) {
        self.id = id
        self.nodeID = nodeID
        self.shareID = shareID
        self.volumeID = volumeID
    }

    public var nodeIdentifier: NodeIdentifier {
        NodeIdentifier(nodeID, shareID, volumeID)
    }
}

// MARK: - Temporary workaround to filter non supported shares
import Combine
public protocol SupportedSharesValidator {
    func isValid(_ id: String) -> Bool
}

public class iOSSupportedSharesValidator: SupportedSharesValidator {
    private let storage: StorageManager

    private lazy var supportedShares: Set<String> = {
        let moc = storage.backgroundContext
        let shareIds = moc.performAndWait {
            do {
                let shares = try storage.fetchSupportedShares(moc: moc)
                return shares.map(\.id)
            } catch {
                return []
            }
        }
        return Set(shareIds)
    }()

    public init(storage: StorageManager) {
        self.storage = storage
    }

    public func isValid(_ id: String) -> Bool {
        return supportedShares.contains(id)
    }
}

class macOSSupportedSharesValidator: SupportedSharesValidator {
    func isValid(_ id: String) -> Bool {
        true
    }
}
