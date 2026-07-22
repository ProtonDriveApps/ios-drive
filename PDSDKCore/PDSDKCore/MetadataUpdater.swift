// Copyright (c) 2024 Proton AG
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
import ProtonCoreNetworking
import ProtonDriveSDK
@preconcurrency import PDClient
@preconcurrency import PDCore
import ProtonCoreUtilities
import CoreData
import FileProvider

// swiftlint:disable:next function_parameter_count

public protocol MetadataUpdaterProtocol {
    func handleRequestAndResponse(
        path: String,
        method: HTTPMethod,
        requestHeaders: [(String, [String])],
        requestBody: JSONDictionary?,
        responseStatusCode: Int,
        responseHeaders: [(String, [String])],
        responseBody: JSONDictionary
    )

    #if os(macOS)
    func finishFileUpload(
        parentFolderUid: SDKNodeUid,
        size: Int,
        fileURL: URL,
        creationDate: TimeInterval,
        modificationDate: TimeInterval,
        result: UploadedFileIdentifiers,
        moc: NSManagedObjectContext
    ) async throws -> Node

    #else
    func finishIOSFileUpload(
        parentFolderUid: SDKNodeUid,
        uploadID: UUID,
        size: Int,
        fileURL: URL,
        creationDate: TimeInterval,
        modificationDate: TimeInterval,
        result: UploadedFileIdentifiers,
        moc: NSManagedObjectContext
    ) async throws -> Node

    #endif
    func finishFileDownload(
        revisionUid: SDKRevisionUid,
        destinationUrl: URL,
        shareID: String,
        moc: NSManagedObjectContext
    ) async throws -> PDCore.Revision

    func finishPhotoDownload(
        photoUid: SDKNodeUid,
        destinationUrl: URL,
        shareID: String,
        moc: NSManagedObjectContext
    ) async throws -> PDCore.Revision

    func finishFileThumbnailDownload(
        fileUid: SDKNodeUid,
        moc: NSManagedObjectContext
    ) async throws

    func finishPhotoThumbnailDownload(
        fileUid: SDKNodeUid,
        moc: NSManagedObjectContext
    ) async throws
    func finishNewRevisionUpload(
        result: UploadedFileIdentifiers,
        size: Int,
        creationDate: Date,
        shareID: String,
        uploadID: UUID,
        moc: NSManagedObjectContext
    ) async throws -> Node

    func finishRename(
        nodeUid: SDKNodeUid,
        moc: NSManagedObjectContext
    ) async throws

    func finishCreateFolder(
        folderNode: FolderNode,
        moc: NSManagedObjectContext
    ) async throws -> CoreDataFolder

    /// Marks the start of an operation that may populate the metadata cache via SDK calls.
    /// Must be paired with a later `endOperation()` on every code path. Prefer `withOperation`
    /// when the operation body fits in a single closure; use the bare pair for streams or
    /// other shapes a closure can't express.
    func beginOperation()

    /// Marks the end of an operation. When the in-flight count returns to zero, every cache
    /// is emptied — orphaned entries from cancellations or thrown operations are cleared
    /// at the next quiescence point.
    func endOperation(context: EndOperationContext)
    /// Releases one paused-upload cache hold when a paused upload is cancelled.
    /// May wipe caches if no operations are in flight and no holds remain.
    func cancelPausedOperation()
    func finishTrashMacNodes(nodes: [SDKNodeUid], moc: NSManagedObjectContext) async throws
    func finishTrashIOSNodes(nodes: [SDKNodeUid], results: [TrashNodeResult], moc: NSManagedObjectContext) async throws -> ([AnyVolumeIdentifier], Error?)
}

extension MetadataUpdaterProtocol {
    /// Brackets `body` with `beginOperation()` / `endOperation()`. Decrements run on every exit
    /// path, including thrown errors.
    public func withOperation<T>(
        _ body: (EndOperationContext) async throws -> T
    ) async rethrows -> T {
        let context = EndOperationContext()
        beginOperation()
        defer { endOperation(context: context) }
        return try await body(context)
    }
}

/// Outcome flags for a `withOperation` / `endOperation` bracket.
///
/// Upload pause/resume spans multiple brackets. Performers set these before
/// `endOperation` runs so `MetadataUpdater` can retain or release cached HTTP
/// responses when `inFlightOperations` returns to zero.
public final class EndOperationContext {
    /// Upload was paused (`successfulCancellation`). Retain cached HTTP responses
    /// until the upload is resumed or cancelled.
    public var retainsPausedOperations = false
    /// Set when servicing a previously paused upload (`operation.isPaused()` at bracket start).
    /// Releases the hold taken at pause when this bracket ends. Re-pause in the same
    /// bracket sets `retainsPausedOperations`, netting to zero (+1 −1).
    public var releasesPausedOperations = false

    // Meaning of (retainsPausedOperations, releasesPausedOperations):
    // (false, false): Normal operation; no pause or resume involved.
    // (false, true): Resuming a previously paused operation.
    // (true, false): Pausing the current operation.
    // (true, true): Operation is resumed and then paused again within the same bracket.
}

public final class MetadataUpdater: MetadataUpdaterProtocol, @unchecked Sendable {

    private typealias CreateFileCall = (volumeID: String, requestBody: JSONDictionary, responseBody: JSONDictionary)
    private typealias CommitRevisionCall = (volumeID: String, nodeID: String, revisionID: String, requestBody: JSONDictionary, responseBody: JSONDictionary)
    private typealias RevisionMetadataCall = (volumeID: String, nodeID: String, revisionID: String, responseBody: JSONDictionary)
    private typealias RenameNodeCall = (volumeID: String, nodeID: String, requestBody: JSONDictionary)
    private typealias CreateFolderCall = (volumeID: String, requestBody: JSONDictionary, responseBody: JSONDictionary)
    private typealias LoadLinkDetailCall = (volumeID: String, requestLinkIDs: [String], responseBody: JSONDictionary)

    /// All caches consolidated under a single lock to minimise synchronisation overhead.
    ///
    /// Cache growth is bounded by `inFlightOperations` and `pausedCacheHoldCount` : every public operation on
    /// `MetadataUpdater` brackets itself with `enterOperation()` / `exitOperation()`,
    /// and when the counter returns to zero `exitOperation` nukes every cache. The counter
    /// and the arrays share the same `Atomic` lock, so the decrement-and-clear is atomic
    /// with respect to any concurrent enter/exit/append — no operation can race with cleanup.
    /// Orphans (e.g. from cancelled or thrown operations that never reach `finish*`) are
    /// cleared at the next quiescence point.
    private struct CacheStore {
        struct CacheEntry<T> {
            let value: T
            let timestamp: Date
        }

        /// Number of operations currently bracketed by `enterOperation` / `exitOperation`.
        /// Caches are emptied whenever this returns to zero.
        var inFlightOperations: Int = 0
        /// Number of paused operations, to prevent caches are emptied unexpectedly
        var pausedOperations = 0

        var createFile: [CacheEntry<CreateFileCall>] = []
        var commitRevision: [CacheEntry<CommitRevisionCall>] = []
        var revisionMetadata: [CacheEntry<RevisionMetadataCall>] = []
        var renameNode: [CacheEntry<RenameNodeCall>] = []
        var createFolder: [CacheEntry<CreateFolderCall>] = []
        var loadFileLinkDetail: [CacheEntry<LoadLinkDetailCall>] = []
        var loadPhotoLinkDetail: [CacheEntry<LoadLinkDetailCall>] = []

        #if DEBUG
        // Survives `exitOperation()` quiescence so tests can inspect requests across operations.
        var recordedRequests: [RecordedRequest] = []
        #endif

        mutating func enterOperation() {
            inFlightOperations += 1
        }

        mutating func exitOperation(context: EndOperationContext) {
            assert(inFlightOperations > 0, "exitOperation() called without a matching enterOperation()")
            inFlightOperations -= 1
            if context.retainsPausedOperations {
                pausedOperations += 1
            }
            if context.releasesPausedOperations {
                pausedOperations -= 1
            }
            assert(pausedOperations >= 0)
            removeCacheIfNeeded()
        }

        mutating func removeCacheIfNeeded() {
            if inFlightOperations == 0, pausedOperations == 0 {
                createFile.removeAll()
                commitRevision.removeAll()
                revisionMetadata.removeAll()
                renameNode.removeAll()
                createFolder.removeAll()
                loadFileLinkDetail.removeAll()
                loadPhotoLinkDetail.removeAll()
            }
        }

        /// Removes every entry matching `predicate` from `array` and returns the value of the
        /// most recent match, or `nil` when nothing matched.
        /// The single-pass loop ensures the predicate is evaluated exactly once per entry
        /// (matters for the throwing predicates that traverse JSON).
        static func splitConsume<T>(
            _ array: inout [CacheEntry<T>],
            where predicate: (CacheEntry<T>) throws -> Bool
        ) rethrows -> T? {
            var matches: [CacheEntry<T>] = []
            var kept: [CacheEntry<T>] = []
            kept.reserveCapacity(array.count)
            for entry in array {
                if try predicate(entry) {
                    matches.append(entry)
                } else {
                    kept.append(entry)
                }
            }
            array = kept
            return matches.max(by: { $0.timestamp < $1.timestamp })?.value
        }

        func diagnosticsSummary() -> String {
            let now = Date()
            func describe<T>(_ name: String, _ array: [CacheEntry<T>]) -> String {
                guard let oldest = array.map(\.timestamp).min() else {
                    return "\(name)=0"
                }
                let age = Int(now.timeIntervalSince(oldest))
                return "\(name)=\(array.count)(oldest=\(age)s)"
            }
            return [
                describe("createFile", createFile),
                describe("commitRevision", commitRevision),
                describe("revisionMetadata", revisionMetadata),
                describe("renameNode", renameNode),
                describe("createFolder", createFolder),
                describe("loadFileLinkDetail", loadFileLinkDetail),
                describe("loadPhotoLinkDetail", loadPhotoLinkDetail),
            ].joined(separator: " ")
        }
    }

    private let caches: Atomic<CacheStore>
    private let storage: StorageManager

    public init(storage: StorageManager) {
        self.storage = storage
        self.caches = .init(.init())
    }

    public func beginOperation() {
        caches.mutate { $0.enterOperation() }
    }

    public func endOperation(context: EndOperationContext) {
        caches.mutate { $0.exitOperation(context: context) }
    }

    public func cancelPausedOperation() {
        caches.mutate { store in
            store.pausedOperations -= 1
            assert(store.pausedOperations >= 0)
            store.removeCacheIfNeeded()
        }
    }

    #if os(macOS)
    public func finishFileUpload(
        parentFolderUid: SDKNodeUid,
        size: Int,
        fileURL: URL,
        creationDate: TimeInterval,
        modificationDate: TimeInterval,
        result: UploadedFileIdentifiers,
        moc: NSManagedObjectContext
    ) async throws -> Node {
        let link = try linkForFileUploader(
            parentFolderUid: parentFolderUid,
            size: size,
            fileURL: fileURL,
            creationDate: creationDate,
            modificationDate: modificationDate,
            result: result
        )

        return try await moc.perform {
            let node = self.storage.updateLink(link, using: moc)
            let parentFolder = try node.parentFolder ?! "Uploaded files should always have a parent folder"
            node.isInheritingOfflineAvailable = parentFolder.isAvailableOffline
            try moc.saveOrRollback()
            return node
        }
    }
    #else
    public func finishIOSFileUpload(
        parentFolderUid: SDKNodeUid,
        uploadID: UUID,
        size: Int,
        fileURL: URL,
        creationDate: TimeInterval,
        modificationDate: TimeInterval,
        result: UploadedFileIdentifiers,
        moc: NSManagedObjectContext
    ) async throws -> Node {
        Log.debug("Finishing \(uploadID)", domain: .sdk)

        let link = try linkForFileUploader(
            parentFolderUid: parentFolderUid,
            size: size,
            fileURL: fileURL,
            creationDate: creationDate,
            modificationDate: modificationDate,
            result: result
        )

        do {
            return try await finishIOSFileUpload(
                parentFolderUid: parentFolderUid,
                uploadID: uploadID,
                result: result,
                link: link,
                fileURL: fileURL,
                moc: moc
            )
        } catch {
            /// Most issues thrown here are due to race condition with events - events creating photo at the same time
            /// as we create it here. If such issue happens, context is rolled back and we'll try to reapply the updates
            /// and return properly configured `Node`.
            Log.error("Retrying saving result fo upload \(uploadID), possibly race condition with events", error: error, domain: .sdk)
            return try await finishIOSFileUpload(
                parentFolderUid: parentFolderUid,
                uploadID: uploadID,
                result: result,
                link: link,
                fileURL: fileURL,
                moc: moc
            )
        }
    }

    private func finishIOSFileUpload(
        parentFolderUid: SDKNodeUid,
        uploadID: UUID,
        result: UploadedFileIdentifiers,
        link: Link,
        fileURL: URL,
        moc: NSManagedObjectContext
    ) async throws -> Node {
        return try await moc.perform { [moc] in
            Log.debug("Finishing \(uploadID) - in context's perform block", domain: .sdk)

            let tempID = AnyVolumeIdentifier(id: uploadID.uuidString, volumeID: parentFolderUid.volumeID)
            let tempNode: CoreDataFile = try CoreDataFile.fetchOrThrow(identifier: tempID, allowSubclasses: true, in: moc)

            if let file = CoreDataFile.fetch(identifier: result.nodeUid.any, allowSubclasses: true, in: moc) {
                // New file has already been created by events. Instead of modifying temporary node,
                // we need to delete it and update the existing one
                Log.info("Deleting temporary upload node, uploaded node is already in DB.", domain: .sdk)
                if let photo = file as? CoreDataPhoto, let temporaryPhoto = tempNode as? CoreDataPhoto {
                    // Need to transfer children from temporary node to the real one
                    temporaryPhoto.children.forEach { childPhoto in
                        photo.addToChildren(childPhoto)
                    }
                    temporaryPhoto.children = []
                }
                moc.delete(tempNode)
            } else {
                // Temporary node needs to be filled with real committed data
                Log.info("Updating temporary upload node.", domain: .sdk)
                tempNode.id = result.nodeUid.nodeID
                for revision in tempNode.revisions {
                    tempNode.removeFromRevisions(revision)
                }
                if let draft = tempNode.activeRevisionDraft {
                    tempNode.activeRevisionDraft = nil
                    moc.delete(draft)
                }
                tempNode.uploadID = nil
                tempNode.isUploading = false
            }

            let node = self.storage.updateLink(link, using: moc)
            let parentFolder = try node.parentFolder ?! "Uploaded files should always have a parent folder"

            // Intentionally don't use `parentFolder.isAvailableOffline` here
            // because `parentFolder` contains a draft child node
            // which causes `parentFolder.isAvailableOffline` to be false
            let isInheritingOfflineAvailable = parentFolder.isMarkedOfflineAvailable || parentFolder.isInheritingOfflineAvailable
            node.isInheritingOfflineAvailable = isInheritingOfflineAvailable
            self.moveClearText(
                fileURL: fileURL,
                isInheritingAvailableOffline: isInheritingOfflineAvailable,
                identifier: node.identifierWithinManagedObjectContext
            )

            try moc.saveOrRollback()

            // When a child photo (e.g. MOV of a live photo) finishes uploading,
            // NSFetchedResultsController won't re-evaluate the parent's
            // relationship-based predicate (ANY children.stateRaw == ...).
            // Refreshing the parent forces the FRC to pick up the change.
            if let photo = node as? CoreDataPhoto, let parentPhoto = photo.parent {
                moc.refresh(parentPhoto, mergeChanges: true)
            }

            return node
        }
    }
    #endif

    public func finishFileDownload(
        revisionUid: SDKRevisionUid,
        destinationUrl: URL,
        shareID: String,
        moc: NSManagedObjectContext
    ) async throws -> PDCore.Revision {
        // 1. find and consume the request that is referencing operation
        let revisionMetadataCall = try consumeFileDownloadCall(revisionUid: revisionUid)

        // this is purely for the cleanup — there might be link details calls in download,
        // but we don't use them, we just don't want them to stay in cache
        _ = consumeLoadFileLinkDetailCallIfExists(volumeID: revisionUid.volumeID, linkIDs: [revisionUid.nodeID])

        // 2. Extract the material
        let revisionMetadataResponseBodyContext = "revisionMetadataCall.responseBody"
        let revisionResponse: JSONDictionary = try obtain("Revision", from: revisionMetadataCall.responseBody, context: revisionMetadataResponseBodyContext)
        let revisionMetadataContext = "\(revisionMetadataResponseBodyContext).Revision"
        let revisionID: RevisionMeta.RevisionID = try obtain("ID", from: revisionResponse, context: revisionMetadataContext)
        let createTime: TimeInterval = try obtain("CreateTime", from: revisionResponse, context: revisionMetadataContext)
        let size: Int = try obtain("Size", from: revisionResponse, context: revisionMetadataContext)
        let manifestSignature: String? = try obtainOptional("ManifestSignature", from: revisionResponse, context: revisionMetadataContext)
        let signatureEmail: String? = try obtainOptional("SignatureEmail", from: revisionResponse, context: revisionMetadataContext)
        let state: NodeState = try obtainWithTransform("State", from: revisionResponse, context: revisionMetadataContext, transform: NodeState.init(rawValue:))
        let checksumVerified: Bool = try obtain("ChecksumVerified", from: revisionResponse, context: revisionMetadataContext)
        let blocksJson: [JSONDictionary] = try obtain("Blocks", from: revisionResponse, context: revisionMetadataContext)
        let blockContext = "\(revisionMetadataContext).Blocks"
        let blocks: [BlockMeta] = try blocksJson.map {
            let index: Int = try obtain("Index", from: $0, context: blockContext)
            let hash: String = try obtain("Hash", from: $0, context: blockContext)
            let URL: URL = try obtainWithTransform("URL", from: $0, context: blockContext, transform: URL.init(string:))
            let encSignature: String? = try obtainOptional("EncSignature", from: $0, context: blockContext)
            let signatureEmail: String? = try obtainOptional("SignatureEmail", from: $0, context: blockContext)
            return BlockMeta(
                index: index,
                hash: hash,
                URL: URL,
                encSignature: encSignature,
                signatureEmail: signatureEmail
            )
        }
        let thumbnail: Int = try obtain("Thumbnail", from: revisionResponse, context: revisionMetadataContext)
        let thumbnailHash: String? = try obtainOptional("ThumbnailHash", from: revisionResponse, context: revisionMetadataContext)
        let thumbnailDownloadUrl: URL? = try obtainOptionalWithTransform("ThumbnailDownloadUrl", from: revisionResponse, context: revisionMetadataContext, transform: URL.init(string:))
        let xAttr: String? = try obtainOptional("XAttr", from: revisionResponse, context: revisionMetadataContext)

        // 3. Create DTOs
        let revisionMeta = RevisionMeta(
            ID: revisionID,
            createTime: createTime,
            size: size,
            manifestSignature: manifestSignature,
            signatureAddress: signatureEmail,
            state: state,
            blocks: blocks,
            thumbnail: thumbnail,
            thumbnailHash: thumbnailHash,
            thumbnailDownloadUrl: thumbnailDownloadUrl,
            XAttr: xAttr
        )

#if os(macOS)
        // attention! we don't pass nodeIdentity.volumeID.value by design, because macOS metadata DB
        // is not yet volume-based! this should be changed once DM-433 is done
        let volumeID = ""
#else
        let volumeID = revisionMetadataCall.volumeID
#endif
        let revisionIdentifier = RevisionIdentifier(
            shareID: shareID,
            fileID: revisionMetadataCall.nodeID,
            revisionID: revisionMetadataCall.revisionID,
            volumeID: volumeID
        )
        let (node, revision) = try await RevisionScanner.performUpdate(
            in: moc, revisionIdentifier: revisionIdentifier, revisionMeta: revisionMeta, storage: storage
        )
        return try await moc.perform {
            node.addToRevisions(revision)
            node.activeRevision = revision
            revision.checksumVerified = checksumVerified
            try moc.saveOrRollback()
            return revision
        }
    }

    public func finishPhotoDownload(
        photoUid: SDKNodeUid,
        destinationUrl: URL,
        shareID: String,
        moc: NSManagedObjectContext
    ) async throws -> PDCore.Revision {
        // 1. Find and consume the revision metadata call for this photo - contains all needed data
        let revisionMetadataCall = try consumePhotoRevisionMetadataCall(photoUid: photoUid)

        // 2. Extract revision material from the response
        let revisionMetadataResponseBodyContext = "revisionMetadataCall.responseBody"
        let revisionResponse: JSONDictionary = try obtain("Revision", from: revisionMetadataCall.responseBody, context: revisionMetadataResponseBodyContext)
        let revisionMetadataContext = "\(revisionMetadataResponseBodyContext).Revision"
        let revisionID: RevisionMeta.RevisionID = try obtain("ID", from: revisionResponse, context: revisionMetadataContext)
        let revisionCreateTime: TimeInterval = try obtain("CreateTime", from: revisionResponse, context: revisionMetadataContext)
        let size: Int = try obtain("Size", from: revisionResponse, context: revisionMetadataContext)
        let manifestSignature: String? = try obtainOptional("ManifestSignature", from: revisionResponse, context: revisionMetadataContext)
        let revisionSignatureEmail: String? = try obtainOptional("SignatureEmail", from: revisionResponse, context: revisionMetadataContext)
        let revisionState: NodeState = try obtainWithTransform("State", from: revisionResponse, context: revisionMetadataContext, transform: NodeState.init(rawValue:))
        let checksumVerified: Bool = try obtain("ChecksumVerified", from: revisionResponse, context: revisionMetadataContext)
        let blocksJson: [JSONDictionary] = try obtain("Blocks", from: revisionResponse, context: revisionMetadataContext)
        let blockContext = "\(revisionMetadataContext).Blocks"
        let blocks: [BlockMeta] = try blocksJson.map {
            let index: Int = try obtain("Index", from: $0, context: blockContext)
            let hash: String = try obtain("Hash", from: $0, context: blockContext)
            let URL: URL = try obtainWithTransform("URL", from: $0, context: blockContext, transform: URL.init(string:))
            let encSignature: String? = try obtainOptional("EncSignature", from: $0, context: blockContext)
            let blockSignatureEmail: String? = try obtainOptional("SignatureEmail", from: $0, context: blockContext)
            return BlockMeta(
                index: index,
                hash: hash,
                URL: URL,
                encSignature: encSignature,
                signatureEmail: blockSignatureEmail
            )
        }
        let thumbnail: Int = try obtain("Thumbnail", from: revisionResponse, context: revisionMetadataContext)
        let thumbnailHash: String? = try obtainOptional("ThumbnailHash", from: revisionResponse, context: revisionMetadataContext)
        let thumbnailDownloadUrl: URL? = try obtainOptionalWithTransform("ThumbnailDownloadUrl", from: revisionResponse, context: revisionMetadataContext, transform: URL.init(string:))
        let xAttr: String? = try obtainOptional("XAttr", from: revisionResponse, context: revisionMetadataContext)

        // TODO: include the Photo-specific attributes in the DTO used for DB update

        // 3. Create DTOs
        let revisionMeta = RevisionMeta(
            ID: revisionID,
            createTime: revisionCreateTime,
            size: size,
            manifestSignature: manifestSignature,
            signatureAddress: revisionSignatureEmail,
            state: revisionState,
            blocks: blocks,
            thumbnail: thumbnail,
            thumbnailHash: thumbnailHash,
            thumbnailDownloadUrl: thumbnailDownloadUrl,
            XAttr: xAttr
        )

#if os(macOS)
        let volumeID = ""
#else
        let volumeID = revisionMetadataCall.volumeID
#endif

        let revisionIdentifier = RevisionIdentifier(
            shareID: shareID,
            fileID: revisionMetadataCall.nodeID,
            revisionID: revisionMetadataCall.revisionID,
            volumeID: volumeID
        )

        // 4. Update metadata DB - update revision only (node should already exist from listing)
        let (node, revision) = try await RevisionScanner.performUpdate(
            in: moc, revisionIdentifier: revisionIdentifier, revisionMeta: revisionMeta, storage: storage
        )
        return try await moc.perform {
            if let photo = node as? PDCore.Photo,
               let photoRevision = revision as? PhotoRevision {
                photo.photoRevision = photoRevision
            } else {
                node.addToRevisions(revision)
                node.activeRevision = revision
            }
            revision.checksumVerified = checksumVerified
            try moc.saveOrRollback()
            return revision
        }
    }

    public func finishFileThumbnailDownload(
        fileUid: SDKNodeUid,
        moc: NSManagedObjectContext
    ) async throws {
        guard let call = try? consumeLoadFileLinkDetailCall(containing: fileUid) else {
            // We can't rely on the fresh metadata call being made on thumbnail download. The SDK uses the cached node info
            // it if has one. In this case, we also must rely on our own cache.
            return
        }

#if os(macOS)
        // attention! we don't pass fileUploadRequest.parentFolderIdentity.volumeID.value by design,
        // because macOS metadata DB is not yet volume-based! this should be changed once DM-433 is done
        let linkVolumeID = ""
#else
        let linkVolumeID = fileUid.volumeID
#endif

        let responseLinks: [JSONDictionary] = try obtain("Links", from: call.responseBody, context: "loadFileLinkDetailCall.responseBody")
        var links: [Link] = []
        for responseLink in responseLinks {
            let link = try parseFileLinkDetails(responseLink, volumeID: linkVolumeID)
            links.append(link)
        }

        try await moc.perform {
            _ = self.storage.updateLinks(links, isRootNodeOptional: true, in: moc)
            try moc.saveIfNeeded()
        }
    }

    public func finishPhotoThumbnailDownload(
        fileUid: SDKNodeUid,
        moc: NSManagedObjectContext
    ) async throws {
        guard let call = try? consumeLoadPhotoLinkDetailCall(containing: fileUid) else {
            // We can't rely on the fresh metadata call being made on thumbnail download. The SDK uses the cached node info
            // it if has one. In this case, we also must rely on our own cache.
            return
        }
        // TODO: consider fallback to `consumeLoadFileLinkDetailCall` - to make it more robust. Atm doesn't seem to be needed

#if os(macOS)
        // attention! we don't pass fileUploadRequest.parentFolderIdentity.volumeID.value by design,
        // because macOS metadata DB is not yet volume-based! this should be changed once DM-433 is done
        let linkVolumeID = ""
#else
        let linkVolumeID = fileUid.volumeID
#endif

        let responseLinks: [JSONDictionary] = try obtain("Links", from: call.responseBody, context: "loadPhotoLinkDetailCall.responseBody")
        var links: [Link] = []
        for responseLink in responseLinks {
            let link = try parsePhotoLinkDetails(responseLink, volumeID: linkVolumeID)
            links.append(link)
        }

        try await moc.perform {
            _ = self.storage.updateLinks(links, isRootNodeOptional: true, in: moc)
            try moc.saveIfNeeded()
        }
    }

    public func finishNewRevisionUpload(
        result: UploadedFileIdentifiers,
        size: Int,
        creationDate: Date,
        shareID: String,
        uploadID: UUID,
        moc: NSManagedObjectContext
    ) async throws -> Node {
        // 1. find and consume the request that is referencing operation
        let commitRevisionCall = try consumeCommitRevisionCall(from: result)

        let commitRevisionRequestContext = "commitRevisionCall.requestBody"
        let revisionSignatureAddress: String? = try obtainOptional("SignatureAddress", from:  commitRevisionCall.requestBody, context: commitRevisionRequestContext)
        let manifestSignature: String = try obtain("ManifestSignature", from:  commitRevisionCall.requestBody, context: commitRevisionRequestContext)
        let xAttr: String = try obtain("XAttr", from:  commitRevisionCall.requestBody, context: commitRevisionRequestContext)

#if os(macOS)
        // attention! we don't pass fileUploadRequest.parentFolderIdentity.volumeID.value by design,
        // because macOS metadata DB is not yet volume-based! this should be changed once DM-433 is done
        let volumeID = ""
#else
        let volumeID = commitRevisionCall.volumeID
#endif

        let revisionMeta = PDClient.Revision(
            ID: result.revisionUid.revisionID,
            createTime: creationDate.timeIntervalSince1970,
            size: size,
            manifestSignature: manifestSignature,
            signatureAddress: revisionSignatureAddress,
            state: .active,
            blocks: [],
            thumbnail: 0,
            thumbnailHash: nil,
            thumbnailDownloadUrl: nil,
            XAttr: xAttr
        )
        let revisionIdentifier = RevisionIdentifier(
            shareID: shareID,
            fileID: result.revisionUid.nodeID,
            revisionID: result.revisionUid.revisionID,
            volumeID: volumeID
        )
        let (file, revision) = try await RevisionScanner.performUpdate(
            in: moc, revisionIdentifier: revisionIdentifier, revisionMeta: revisionMeta, storage: storage
        )
        return try await moc.perform {
            #if os(iOS)
            let tempID = AnyVolumeIdentifier(id: uploadID.uuidString, volumeID: volumeID)
            if let temp = Node.fetch(identifier: tempID, allowSubclasses: true, in: moc) {
                moc.delete(temp)
            }
            #endif
            file.addToRevisions(revision)
            file.activeRevision = revision
            file.modifiedDate = Date()
            try moc.saveOrRollback()
            return file
        }
    }

    public func finishRename(nodeUid: SDKNodeUid, moc: NSManagedObjectContext) async throws {
        let renameNodeCall = try consumeRenameNodeCall(nodeUid: nodeUid)

        let renameNodeCallRequestContext = "renameNodeCall.requestBody"
        let name: String = try obtain("Name", from: renameNodeCall.requestBody, context: renameNodeCallRequestContext)
        let hash: String = try obtain("Hash", from: renameNodeCall.requestBody, context: renameNodeCallRequestContext)
        let mimeType: String? = try? obtain("MIMEType", from:  renameNodeCall.requestBody, context: renameNodeCallRequestContext)

        try await moc.perform { [moc] in
            let node = Node.fetch(identifier: nodeUid.any, allowSubclasses: true, in: moc)
            node?.name = name
            node?.nodeHash = hash
            if let mimeType, !mimeType.isEmpty {
                node?.mimeType = mimeType
            }
            try moc.saveIfNeeded()
        }
    }

    public func finishCreateFolder(folderNode: FolderNode, moc: NSManagedObjectContext) async throws -> CoreDataFolder {
        // 1. find and consume the request that is referencing operation
        let createFolderCall = try consumeCreateFolderCall(from: folderNode)

        // 2. Extract the material
        let createFolderRequestContext = "createFolderCallCache.requestBody"
        let hash: String = try obtain("Hash", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let xattr: String = try obtain("XAttr", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let nodePassphrase: String = try obtain("NodePassphrase", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let nodeHashKey: String = try obtain("NodeHashKey", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let signatureEmail: String = try obtain("SignatureEmail", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let parentLinkID: String = try obtain("ParentLinkID", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let nodePassphraseSignature: String = try obtain("NodePassphraseSignature", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let name: String = try obtain("Name", from: createFolderCall.requestBody, context: createFolderRequestContext)
        let nodeKey: String = try obtain("NodeKey", from: createFolderCall.requestBody, context: createFolderRequestContext)

        // 3. Build DTOses
#if os(macOS)
        // attention! we don't pass fileUploadRequest.parentFolderIdentity.volumeID.value by design,
        // because macOS metadata DB is not yet volume-based! this should be changed once DM-433 is done
        let volumeID = ""
#else
        let volumeID = createFolderCall.volumeID
#endif

        let modificationDate = Date().timeIntervalSince1970 // This is Proton link modification time, not the clear text modification time.
        let link = Link(
            linkID: folderNode.uid.nodeID,
            parentLinkID: parentLinkID,
            volumeID: volumeID,
            type: .folder,
            name: name,
            nameSignatureEmail: nil,
            hash: hash,
            state: .active,
            expirationTime: nil,
            size: 0,
            MIMEType: Folder.mimeType,
            attributes: 1, // taken from the observed network response, not used in NodeItem creation
            permissions: 7, // taken from the observed network response, not used in NodeItem creation
            nodeKey: nodeKey,
            nodePassphrase: nodePassphrase,
            nodePassphraseSignature: nodePassphraseSignature,
            signatureEmail: signatureEmail,
            createTime: modificationDate,
            modifyTime: modificationDate,
            trashed: nil,
            sharingDetails: nil,
            nbUrls: 0,
            activeUrls: 0,
            urlsExpired: 0,
            XAttr: xattr,
            fileProperties: nil,
            folderProperties: FolderProperties(nodeHashKey: nodeHashKey),
            documentProperties: nil
        )

        // 4. Update metadata DB
        return try await moc.perform { [moc] in
            #if os(iOS)
            let parentID = AnyVolumeIdentifier(id: parentLinkID, volumeID: volumeID)
            let parentFolder: CoreDataFolder = try CoreDataFolder.fetchOrThrow(identifier: parentID, in: moc)
            let isInheritingOfflineAvailable = parentFolder.isAvailableOffline
            let node = self.storage.updateLink(link, using: moc)
            node.isInheritingOfflineAvailable = isInheritingOfflineAvailable
            #else
            let node = self.storage.updateLink(link, using: moc)
            let isInheritingOfflineAvailable = node.parentFolder?.isAvailableOffline ?? false
            node.isInheritingOfflineAvailable = isInheritingOfflineAvailable
            #endif
            try moc.saveOrRollback()
            let folder = node as? CoreDataFolder
            return try folder ?! "Failed to cast node to CoreDataFolder"
        }

    }

    public func finishTrashMacNodes(nodes: [SDKNodeUid], moc: NSManagedObjectContext) async throws {
        try await moc.perform { [moc] in
            let nodeIDs = nodes.map(\.nodeID)
            let trashedNodes = self.storage.fetchNodes(ids: nodeIDs, moc: moc)
            trashedNodes.forEach { node in
                node.state = .deleted
                node.isMarkedOfflineAvailable = false
            }
            try moc.saveOrRollback()
        }
    }

    public func finishTrashIOSNodes(
        nodes: [SDKNodeUid],
        results: [TrashNodeResult],
        moc: NSManagedObjectContext
    ) async throws -> ([AnyVolumeIdentifier], Error?) {
        let failedLinks = Set(
            results.compactMap { result -> String? in
                guard let errorCode = result.error?.primaryCode else { return nil }
                return errorCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue ? nil : result.nodeUid.nodeID
            }
        )

        let trashedLinks = nodes.filter { !failedLinks.contains($0.nodeID) }.map(\.any)

        let performer = NodeTreeTrashPerformer()
        let affectedFiles = try await performer.performAndSave(to: trashedLinks, in: moc)
        let error = results.first(where: { $0.error != nil && $0.error?.primaryCode != APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue })?.error
        return (affectedFiles.map { $0.identifier.any() }, error)
    }

    public func handleRequestAndResponse(
        path: String,
        method: HTTPMethod,
        requestHeaders: [(String, [String])],
        requestBody: JSONDictionary?,
        responseStatusCode: Int,
        responseHeaders: [(String, [String])],
        responseBody: JSONDictionary
    ) {
        let now = Date()
        caches.mutate { store in
            #if DEBUG
            store.recordedRequests.append(
                RecordedRequest(method: method, path: path, statusCode: responseStatusCode, timestamp: now)
            )
            #endif

            // Identify the request shape and whether a missing operation bracket should warn
            // in DEBUG. The two loadLinkDetail variants are excluded because listing/enumerate
            // flows hit POST /links legitimately without being wrapped.
            let match: (append: (inout CacheStore) -> Void, warnIfNotInOperation: Bool)?

            if let (volumeID, requestBody) = self.identifyCreateFileCall(path: path, method: method, requestBody: requestBody) {
                match = (
                    append: { $0.createFile.append(.init(value: (volumeID: volumeID, requestBody: requestBody, responseBody: responseBody), timestamp: now)) },
                    warnIfNotInOperation: true
                )
            } else if let (volumeID, nodeID, revisionID, requestBody) = self.identifyCommitRevisionCall(path: path, method: method, requestBody: requestBody) {
                match = (
                    append: { $0.commitRevision.append(.init(value: (volumeID: volumeID, nodeID: nodeID, revisionID: revisionID, requestBody: requestBody, responseBody: responseBody), timestamp: now)) },
                    warnIfNotInOperation: true
                )
            } else if let (volumeID, nodeID, revisionID) = self.identifyRevisionMetadataCall(path: path, method: method) {
                match = (
                    append: { $0.revisionMetadata.append(.init(value: (volumeID: volumeID, nodeID: nodeID, revisionID: revisionID, responseBody: responseBody), timestamp: now)) },
                    warnIfNotInOperation: true
                )
            } else if let (volumeID, nodeID, requestBody) = self.identifyRenameNodeCall(path: path, method: method, requestBody: requestBody) {
                match = (
                    append: { $0.renameNode.append(.init(value: (volumeID: volumeID, nodeID: nodeID, requestBody: requestBody), timestamp: now)) },
                    warnIfNotInOperation: true
                )
            } else if let (volumeID, requestBody) = self.identifyCreateFolderCall(path: path, method: method, requestBody: requestBody) {
                match = (
                    append: { $0.createFolder.append(.init(value: (volumeID: volumeID, requestBody: requestBody, responseBody: responseBody), timestamp: now)) },
                    warnIfNotInOperation: true
                )
            } else if let (volumeID, requestLinkIDs) = self.identifyFileLoadLinkDetailCall(path: path, method: method, requestBody: requestBody) {
                match = (
                    append: { $0.loadFileLinkDetail.append(.init(value: (volumeID: volumeID, requestLinkIDs: requestLinkIDs, responseBody: responseBody), timestamp: now)) },
                    warnIfNotInOperation: false
                )
            } else if let (volumeID, requestLinkIDs) = self.identifyPhotoLoadLinkDetailCall(path: path, method: method, requestBody: requestBody) {
                match = (
                    append: { $0.loadPhotoLinkDetail.append(.init(value: (volumeID: volumeID, requestLinkIDs: requestLinkIDs, responseBody: responseBody), timestamp: now)) },
                    warnIfNotInOperation: false
                )
            } else {
                match = nil
            }

            guard let match else { return }

            guard store.inFlightOperations > 0 else {
                #if DEBUG
                if match.warnIfNotInOperation {
                    Log.warning(
                        "MetadataUpdater: cacheable response \(method.rawValue) \(path) received without operation bracketing — likely a missed withOperation wrap",
                        domain: .sdk
                    )
                }
                #endif
                return
            }

            match.append(&store)
        }

        #if DEBUG
        print("""
              [CALL] \(method.rawValue) \(path)
              [REQUEST] \(requestBody?.description ?? "none")
              [RESPONSE] \(responseBody)
              """)
        #endif
    }
}

// MARK: - Call identification helpers

extension MetadataUpdater {

    private func identifyCreateFileCall(
        path: String, method: HTTPMethod, requestBody: JSONDictionary?
    ) -> (String, JSONDictionary)? {
        guard method == .post,
              let match = path.firstMatch(of: #/\/drive.*\/volumes\/(.+)\/files$/#),
              let requestBody
        else {
            return nil
        }
        let volumeID = String(match.output.1)
        return (volumeID, requestBody)
    }

    private func identifyNewRevisionCall(
        path: String,
        method: HTTPMethod,
        requestBody: JSONDictionary?
    ) -> (String, String, JSONDictionary)? {
        guard
            method == .post,
            let match = path.firstMatch(of: #/\/drive.*\/volumes\/(.+)\/files\/(.+)/revisions$/#),
            let requestBody
        else { return nil }
        let volumeID = String(match.1)
        let nodeID = String(match.2)
        return (volumeID, nodeID, requestBody)
    }

    private func identifyCommitRevisionCall(
        path: String, method: HTTPMethod, requestBody: JSONDictionary?
    ) -> (String, String, String, JSONDictionary)? {
        guard method == .put,
              let match = path.firstMatch(of: #/\/drive.*\/volumes\/(.+)\/files\/(.+)\/revisions\/(.+)/#),
              let requestBody
        else {
            return nil
        }
        let volumeID = String(match.output.1)
        let nodeID = String(match.output.2)
        let revisionID = String(match.output.3)
        return (volumeID, nodeID, revisionID, requestBody)
    }

    private func identifyRevisionMetadataCall(path: String, method: HTTPMethod) -> (String, String, String)? {
        guard method == .get,
              let match = path.firstMatch(of: #/\/drive.*\/volumes\/(.+)\/files\/(.+)\/revisions\/(.+)(\/|\?)/#)
        else {
            return nil
        }
        let volumeID = String(match.output.1)
        let nodeID = String(match.output.2)
        let revisionID = String(match.output.3)
        return (volumeID, nodeID, revisionID)
    }

    private func identifyRenameNodeCall(
        path: String, method: HTTPMethod, requestBody: JSONDictionary?
    ) -> (String, String, JSONDictionary)? {
        guard
            method == .put,
            let match = path.firstMatch(of: #/\/drive.*\/volumes\/(.+)\/links\/(.+)\/rename/#),
            let requestBody
        else { return nil }
        let volumeID = String(match.output.1)
        let nodeID = String(match.output.2)
        return (volumeID, nodeID, requestBody)
    }

    private func identifyCreateFolderCall(
        path: String, method: HTTPMethod, requestBody: JSONDictionary?,
    ) -> (String, JSONDictionary)? {
        guard
            method == .post,
            let match = path.firstMatch(of: #/\/drive.*\/volumes\/(.+)\/folders/#),
            let requestBody
        else { return nil }
        let volumeID = String(match.output.1)
        return (volumeID, requestBody)
    }

    private func identifyFileLoadLinkDetailCall(
        path: String,
        method: HTTPMethod,
        requestBody: JSONDictionary?
    ) -> (String, [String])? {
        guard
            method == .post,
            let match = path.firstMatch(of: #/\/drive(?:\/v\d+)?\/volumes\/(.+)\/links/#),
            let requestBody,
            let requestLinkIDs = try? obtainOptional("LinkIDs", from: requestBody, context: "Fetch.metadata.requestBody") as [String]?
        else { return nil }
        let volumeID = String(match.output.1)
        return (volumeID, requestLinkIDs)
    }

    private func identifyPhotoLoadLinkDetailCall(
        path: String,
        method: HTTPMethod,
        requestBody: JSONDictionary?
    ) -> (String, [String])? {
        guard
            method == .post,
            let match = path.firstMatch(of: #/\/drive(?:\/v\d+)?\/photos\/volumes\/(.+)\/links/#),
            let requestBody,
            let requestLinkIDs = try? obtainOptional("LinkIDs", from: requestBody, context: "Fetch.photo.metadata.requestBody") as [String]?
        else { return nil }
        let volumeID = String(match.output.1)
        return (volumeID, requestLinkIDs)
    }
}

// MARK: - JSON traversing helpers

extension MetadataUpdater {

    func obtain<T>(_ field: String, from json: JSONDictionary, context: String) throws -> T {
        guard let value = json[field] as? T
        else { throw MetadataUpdateError.fieldMissing(missingField: "\(context).\(field)") }
        return value
    }

    private func obtainWithTransform<I, T>(
        _ field: String, from json: JSONDictionary, context: String, transform: (I) -> T?
    ) throws -> T {
        let value: I = try obtain(field, from: json, context: context)
        return try performTransform(value: value, field: field, transform: transform)
    }

    func obtainOptional<T>(_ field: String, from json: JSONDictionary, context: String) throws -> T? {
        guard let value = json[field] else { return nil }
        // JSONDictionary represents json's `null` as NSNull
        if value is NSNull { return nil }
        guard let value = value as? T
        else { throw MetadataUpdateError.fieldMissing(missingField: "\(context).\(field)") }
        return value
    }

    private func obtainOptionalWithTransform<I, T>(
        _ field: String, from json: JSONDictionary, context: String, transform: (I) -> T?
    ) throws -> T? {
        guard let value: I = try obtainOptional(field, from: json, context: context) else { return nil }
        return try performTransform(value: value, field: field, transform: transform)
    }

    private func performTransform<I, T>(value: I, field: String, transform: (I) -> T?) throws -> T {
        guard let transformedValue = transform(value)
        else { throw MetadataUpdateError.unexpectedFieldValue(field: field, value: "\(value)") }
        return transformedValue
    }

    /// Builds a `noCachedResponse` error and logs a snapshot of cache contents alongside it.
    /// The snapshot helps distinguish "operation never cached" from "entry expired" from
    /// "accumulation pressure" when these failures show up in production telemetry.
    private func makeNoCachedResponseError(_ missingResponse: String) -> MetadataUpdateError {
        let error = MetadataUpdateError.noCachedResponse(missingResponse: missingResponse)
        let snapshot = caches.value.diagnosticsSummary()
        Log.error(
            "MetadataUpdater cache miss for \(missingResponse). Cache state: \(snapshot)",
            error: error,
            domain: .sdk
        )
        return error
    }

    // MARK: - Cache match predicates

    private func revisionMetadataMatches(
        _ entry: CacheStore.CacheEntry<RevisionMetadataCall>,
        revisionUid: SDKRevisionUid
    ) -> Bool {
        let (volumeID, nodeID, revisionID, _) = entry.value
        return revisionUid.volumeID == volumeID && revisionUid.nodeID == nodeID && revisionUid.revisionID == revisionID
    }

    private func revisionMetadataMatches(
        _ entry: CacheStore.CacheEntry<RevisionMetadataCall>,
        photoUid: SDKNodeUid
    ) -> Bool {
        let (volumeID, nodeID, _, _) = entry.value
        return photoUid.volumeID == volumeID && photoUid.nodeID == nodeID
    }

    private func createFileMatches(
        _ entry: CacheStore.CacheEntry<CreateFileCall>,
        result: UploadedFileIdentifiers,
        parentFolderUid: SDKNodeUid
    ) throws -> Bool {
        let (volumeID, requestBody, responseBody) = entry.value
        let createFileRequestContext = "createFileCallCache.requestBody"
        let parentLinkID: String = try obtain("ParentLinkID", from: requestBody, context: createFileRequestContext)
        let responseBodyContext = "createFileCallCache.responseBody"

        guard let file: JSONDictionary = try? obtain("File", from: responseBody, context: responseBodyContext) else {
            // we handle the lack of "File" gently because this is the case of the error responses
            return false
        }
        let fileContext = "\(responseBodyContext).File"
        let nodeID: String = try obtain("ID", from: file, context: fileContext)
        let revisionID: String = try obtain("RevisionID", from: file, context: fileContext)

        return parentFolderUid.volumeID == volumeID && parentFolderUid.nodeID == parentLinkID
            && result.nodeUid.volumeID == volumeID && result.nodeUid.nodeID == nodeID
            && result.revisionUid.volumeID == volumeID && result.revisionUid.nodeID == nodeID && result.revisionUid.revisionID == revisionID
    }

    private func commitRevisionMatches(
        _ entry: CacheStore.CacheEntry<CommitRevisionCall>,
        result: UploadedFileIdentifiers
    ) -> Bool {
        let (volumeID, nodeID, revisionID, _, _) = entry.value
        return result.nodeUid.volumeID == volumeID
            && result.nodeUid.nodeID == nodeID
            && result.revisionUid.volumeID == volumeID
            && result.revisionUid.nodeID == nodeID
            && result.revisionUid.revisionID == revisionID
    }

    private func renameNodeMatches(
        _ entry: CacheStore.CacheEntry<RenameNodeCall>,
        nodeUid: SDKNodeUid
    ) -> Bool {
        let (volumeID, nodeID, _) = entry.value
        return nodeUid.volumeID == volumeID && nodeUid.nodeID == nodeID
    }

    private func createFolderMatches(
        _ entry: CacheStore.CacheEntry<CreateFolderCall>,
        folderNode: FolderNode
    ) throws -> Bool {
        let (volumeID, requestBody, responseBody) = entry.value
        let createFolderContext = "createFolderCallCache.requestBody"
        let parentLinkID: String = try obtain("ParentLinkID", from: requestBody, context: createFolderContext)

        let responseContext = "createFolderCallCache.responseBody"
        let folder: JSONDictionary = try obtain("Folder", from: responseBody, context: responseContext)
        let idContext = "\(responseContext).ID"
        let folderID: String = try obtain("ID", from: folder, context: idContext)

        return volumeID == folderNode.parentUid?.volumeID
            && parentLinkID == folderNode.parentUid?.nodeID
            && folderID == folderNode.uid.nodeID
    }

    private func loadLinkDetailMatches(
        _ entry: CacheStore.CacheEntry<LoadLinkDetailCall>,
        volumeID: String,
        linkIDs: [String]
    ) -> Bool {
        let (requestVolumeID, requestLinkIDs, _) = entry.value
        return requestVolumeID == volumeID && requestLinkIDs.sorted() == linkIDs.sorted()
    }
    
    private func loadLinkDetailContains(
        _ entry: CacheStore.CacheEntry<LoadLinkDetailCall>,
        volumeID: String,
        linkID: String
    ) -> Bool {
        let (requestVolumeID, requestLinkIDs, _) = entry.value
        return requestVolumeID == volumeID && requestLinkIDs.contains(linkID)
    }

    // MARK: - Cache consume helpers

    /// Finds and removes all matching revision metadata calls from the cache, returning the most recent.
    private func consumeFileDownloadCall(revisionUid: SDKRevisionUid) throws -> RevisionMetadataCall {
        var result: RevisionMetadataCall?
        caches.mutate { store in
            result = CacheStore.splitConsume(&store.revisionMetadata) { entry in
                self.revisionMetadataMatches(entry, revisionUid: revisionUid)
            }
        }
        guard let result else { throw makeNoCachedResponseError("revisionMetadataCallCache") }
        return result
    }

    /// Finds and removes all matching photo revision metadata calls from the cache, returning the most recent.
    private func consumePhotoRevisionMetadataCall(photoUid: SDKNodeUid) throws -> RevisionMetadataCall {
        var result: RevisionMetadataCall?
        caches.mutate { store in
            result = CacheStore.splitConsume(&store.revisionMetadata) { entry in
                self.revisionMetadataMatches(entry, photoUid: photoUid)
            }
        }
        guard let result else { throw makeNoCachedResponseError("revisionMetadataCallCache for photo") }
        return result
    }

    /// Finds and removes all matching create file calls from the cache, returning the most recent.
    private func consumeCreateFileCall(from result: UploadedFileIdentifiers, and parentFolderUid: SDKNodeUid) throws -> CreateFileCall {
        var consumeResult: Result<CreateFileCall?, Error> = .success(nil)
        caches.mutate { store in
            do {
                let value = try CacheStore.splitConsume(&store.createFile) { entry in
                    try self.createFileMatches(entry, result: result, parentFolderUid: parentFolderUid)
                }
                consumeResult = .success(value)
            } catch {
                consumeResult = .failure(error)
            }
        }
        guard let createFileCall = try consumeResult.get() else {
            throw makeNoCachedResponseError("createFileCallCache")
        }
        return createFileCall
    }

    /// Finds and removes all matching commit revision calls from the cache, returning the most recent.
    private func consumeCommitRevisionCall(from result: UploadedFileIdentifiers) throws -> CommitRevisionCall {
        var consumeResult: CommitRevisionCall?
        caches.mutate { store in
            consumeResult = CacheStore.splitConsume(&store.commitRevision) { entry in
                self.commitRevisionMatches(entry, result: result)
            }
        }
        guard let consumeResult else { throw makeNoCachedResponseError("commitRevisionCallCache") }
        return consumeResult
    }

    /// Finds and removes all matching rename node calls from the cache, returning the most recent.
    private func consumeRenameNodeCall(nodeUid: SDKNodeUid) throws -> RenameNodeCall {
        var result: RenameNodeCall?
        caches.mutate { store in
            result = CacheStore.splitConsume(&store.renameNode) { entry in
                self.renameNodeMatches(entry, nodeUid: nodeUid)
            }
        }
        guard let result else { throw makeNoCachedResponseError("renameNodeCallCache") }
        return result
    }

    /// Finds and removes all matching create folder calls from the cache, returning the most recent.
    private func consumeCreateFolderCall(from folderNode: FolderNode) throws -> CreateFolderCall {
        var consumeResult: Result<CreateFolderCall?, Error> = .success(nil)
        caches.mutate { store in
            do {
                let value = try CacheStore.splitConsume(&store.createFolder) { entry in
                    try self.createFolderMatches(entry, folderNode: folderNode)
                }
                consumeResult = .success(value)
            } catch {
                consumeResult = .failure(error)
            }
        }
        guard let createFolderCall = try consumeResult.get() else { throw makeNoCachedResponseError("createFolderCallCache") }
        return createFolderCall
    }
    
    /// Finds and removes the matching load link detail call from the cache.
    /// Said load response may contain other link's details
    private func consumeLoadFileLinkDetailCall(containing linkUid: SDKNodeUid) throws -> LoadLinkDetailCall {
        var result: LoadLinkDetailCall?
        let volumeID = linkUid.volumeID
        let nodeID = linkUid.nodeID
        caches.mutate { store in
            result = CacheStore.splitConsume(&store.loadFileLinkDetail) { entry in
                self.loadLinkDetailContains(entry, volumeID: volumeID, linkID: nodeID)
            }
        }
        guard let result else { throw MetadataUpdateError.noCachedResponse(missingResponse: "loadFileLinkDetailCallCache") }
        return result
    }

    /// Finds and removes all matching load link detail calls from the cache, returning the most recent.
    private func consumeLoadFileLinkDetailCallIfExists(volumeID: String, linkIDs: [String]) -> LoadLinkDetailCall? {
        var result: LoadLinkDetailCall?
        caches.mutate { store in
            result = CacheStore.splitConsume(&store.loadFileLinkDetail) { entry in
                self.loadLinkDetailMatches(entry, volumeID: volumeID, linkIDs: linkIDs)
            }
        }
        return result
    }
    
    /// Finds and removes the matching load link detail call from the cache.
    /// Said load response may contain other link's details
    private func consumeLoadPhotoLinkDetailCall(containing linkUid: SDKNodeUid) throws -> LoadLinkDetailCall {
        var result: LoadLinkDetailCall?
        let volumeID = linkUid.volumeID
        let nodeID = linkUid.nodeID
        caches.mutate { store in
            result = CacheStore.splitConsume(&store.loadPhotoLinkDetail) { entry in
                let (requestVolumeID, requestLinkIDs, _) = entry.value
                return requestVolumeID == volumeID && requestLinkIDs.contains(nodeID)
            }
        }
        guard let result else { throw makeNoCachedResponseError("loadPhotoLinkDetailCallCache") }
        return result
    }
}

// MARK: - Private helper
extension MetadataUpdater {
    #if os(iOS)
    private func moveClearText(fileURL: URL, isInheritingAvailableOffline: Bool, identifier: NodeIdentifier) {
        if isInheritingAvailableOffline {
            // Move to permanent storage
            let path = PDFileManager
                .fileURL(for: identifier, prefix: nil, storageType: .permanent, shouldCreate: true)
            try? FileManager.default.moveItem(at: fileURL, to: path)
        } else {
            // Move to transient storage
            let path = PDFileManager
                .fileURL(for: identifier, prefix: nil, storageType: .temporary, shouldCreate: true)
            try? FileManager.default.moveItem(at: fileURL, to: path)
        }
    }
    #endif
}

// MARK: - Parse link details
extension MetadataUpdater {

    private func linkForFileUploader(
        parentFolderUid: SDKNodeUid,
        size: Int,
        fileURL: URL,
        creationDate: TimeInterval,
        modificationDate: TimeInterval,
        result: UploadedFileIdentifiers,
    ) throws -> Link {
        // 1. find the requests that are referencing operation
        let createFileCall = try consumeCreateFileCall(from: result, and: parentFolderUid)
        let commitRevisionCall = try consumeCommitRevisionCall(from: result)

        // 2. Extract the material
        let createFileRequestContext = "createFileCallCache.requestBody"
        let hash: String = try obtain("Hash", from: createFileCall.requestBody, context: createFileRequestContext)
        let mimeType: String = try obtain("MIMEType", from: createFileCall.requestBody, context: createFileRequestContext)
        let parentLinkID: String = try obtain("ParentLinkID", from: createFileCall.requestBody, context: createFileRequestContext)
        let nodePassphraseSignature: String = try obtain("NodePassphraseSignature", from: createFileCall.requestBody, context: createFileRequestContext)
        let fileSignatureAddress: String = try obtain("SignatureAddress", from: createFileCall.requestBody, context: createFileRequestContext)
        let contentKeyPacket: String = try obtain("ContentKeyPacket", from: createFileCall.requestBody, context: createFileRequestContext)
        let name: String = try obtain("Name", from: createFileCall.requestBody, context: createFileRequestContext)
        let nodePassphrase: String = try obtain("NodePassphrase", from: createFileCall.requestBody, context: createFileRequestContext)
        let contentKeyPacketSignature: String = try obtain("ContentKeyPacketSignature", from: createFileCall.requestBody, context: createFileRequestContext)
        let nodeKey: String = try obtain("NodeKey", from: createFileCall.requestBody, context: createFileRequestContext)

        let commitRevisionRequestContext = "commitRevisionCall.requestBody"
        let extendedAttributes: String = try obtain("XAttr", from:  commitRevisionCall.requestBody, context: commitRevisionRequestContext)
        let revisionSignatureAddress: String = try obtain("SignatureAddress", from:  commitRevisionCall.requestBody, context: commitRevisionRequestContext)
        let manifestSignature: String = try obtain("ManifestSignature", from:  commitRevisionCall.requestBody, context: commitRevisionRequestContext)
        let photoAttributes: JSONDictionary? = try? obtain("Photo", from: commitRevisionCall.requestBody, context: commitRevisionRequestContext)

        // 3. Build DTOses
        var photo: PDClient.Photo?
        var photoTags: [Int]?
        if let photoAttributes {
            let photoAttributeContext = "\(commitRevisionRequestContext).photo"
            let contentHash: String = try obtain("ContentHash", from: photoAttributes, context: photoAttributeContext)
            let captureTime: TimeInterval = try obtain("CaptureTime", from: photoAttributes, context: photoAttributeContext)
            let mainPhotoLinkID: String? = try? obtain("MainPhotoLinkID", from: photoAttributes, context: photoAttributeContext)
            let tags: [Int] = try obtain("Tags", from: photoAttributes, context: photoAttributeContext)
            photo = .init(
                linkID: result.nodeUid.nodeID,
                captureTime: captureTime,
                addedTime: Date(),
                mainPhotoLinkID: mainPhotoLinkID,
                relatedPhotosLinkIDs: [], // This can be empty - assuming at time of upload there are no "child photos" present on BE anyway
                hash: hash,
                contentHash: contentHash
            )
            photoTags = tags
        }
        let activeRevision = RevisionShort(
            ID: result.revisionUid.revisionID,
            createTime: creationDate,
            size: size,
            manifestSignature: manifestSignature,
            signatureAddress: revisionSignatureAddress,
            state: .active,
            thumbnail: 0,
            photo: photo
        )
#if os(macOS)
        // attention! we don't pass fileUploadRequest.parentFolderIdentity.volumeID.value by design,
        // because macOS metadata DB is not yet volume-based! this should be changed once DM-433 is done
        let volumeID = ""
        let modificationDate = modificationDate
#else
        let volumeID = createFileCall.volumeID
        let modificationDate = Date().timeIntervalSince1970 // This is Proton link modification time, not the clear text modification time.
#endif
        var photoProperties: PhotoProperties?
        if let photoTags {
            photoProperties = .init(albums: [], tags: photoTags)
        }
        let link = Link(
            linkID: result.nodeUid.nodeID,
            parentLinkID: parentLinkID,
            volumeID: volumeID,
            type: .file,
            name: name,
            nameSignatureEmail: fileSignatureAddress,
            hash: hash,
            state: .active,
            expirationTime: nil,
            size: size,
            MIMEType: mimeType,
            attributes: 1, // taken from the observed network response, not used in NodeItem creation
            permissions: 7, // taken from the observed network response, not used in NodeItem creation
            nodeKey: nodeKey,
            nodePassphrase: nodePassphrase,
            nodePassphraseSignature: nodePassphraseSignature,
            signatureEmail: fileSignatureAddress,
            createTime: creationDate,
            modifyTime: modificationDate,
            trashed: nil,
            sharingDetails: nil,
            nbUrls: 0,
            activeUrls: 0,
            urlsExpired: 0,
            XAttr: extendedAttributes,
            fileProperties: FileProperties(contentKeyPacket: contentKeyPacket,
                                           contentKeyPacketSignature: contentKeyPacketSignature,
                                           activeRevision: activeRevision),
            folderProperties: nil,
            documentProperties: nil,
            photoProperties: photoProperties
        )
        return link
    }
}

#if DEBUG

// MARK: - Testing support
extension MetadataUpdater {
    /// Cache counts for unit testing verification.
    /// These allow tests to verify that caches are properly cleaned after consume operations.
    var createFileCallCacheCount: Int { caches.value.createFile.count }
    var commitRevisionCallCacheCount: Int { caches.value.commitRevision.count }
    var revisionMetadataCallCacheCount: Int { caches.value.revisionMetadata.count }
    var renameNodeCallCacheCount: Int { caches.value.renameNode.count }
    var createFolderCallCacheCount: Int { caches.value.createFolder.count }
    var loadFileLinkDetailCallCacheCount: Int { caches.value.loadFileLinkDetail.count }
    var loadPhotoLinkDetailCallCacheCount: Int { caches.value.loadPhotoLinkDetail.count }

    /// Total count of all cached calls, useful for verifying overall cache cleanup.
    var totalCachedCallsCount: Int {
        createFileCallCacheCount
            + commitRevisionCallCacheCount
            + revisionMetadataCallCacheCount
            + renameNodeCallCacheCount
            + createFolderCallCacheCount
            + loadFileLinkDetailCallCacheCount
            + loadPhotoLinkDetailCallCacheCount
    }
}

// MARK: - Request introspection (DEBUG-only)

public struct RecordedRequest: Sendable, Equatable {
    public let method: HTTPMethod
    public let path: String
    public let statusCode: Int
    public let timestamp: Date
}

extension MetadataUpdater {
    public var recordedRequests: [RecordedRequest] { caches.value.recordedRequests }

    public func recordedRequests(since index: Int) -> [RecordedRequest] {
        let all = caches.value.recordedRequests
        guard index <= all.count else { return [] }
        return Array(all[index...])
    }

    public func clearRecordedRequests() {
        caches.mutate { $0.recordedRequests.removeAll() }
    }
}

#endif

