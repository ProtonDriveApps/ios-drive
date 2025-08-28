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

import CoreData
import FileProvider
import PDClient

private struct ErrorWithLink: Error { let link: Link; let error: Error }

public final class CancelToken {
    public var onCancel: () -> Void = { }
    // TODO: consider thread-safety
    public var isCancelled: Bool = false
    public init() { }
    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel()
    }
}

public protocol RefreshingNodesServiceProtocol {
    func refreshUsingEagerSyncApproach(
        root: Folder,
        shouldIncludeDeletedItems: Bool,
        cancelToken: CancelToken?,
        onNodeRefreshed: @MainActor @escaping (Int) -> Void
    ) async throws
    
    func refreshUsingDirtyNodesApproach(
        root: Folder,
        resumingOnRetry: Bool,
        progressClosure: @escaping (Int, Int) -> Void
    ) async throws
    
    func hasDirtyNodes(root: Folder) async throws -> Bool
    
    func sendRefreshNotFinishedSentryEvent(root: Folder, error: Error?) async
}

public extension RefreshingNodesServiceProtocol {
    func refreshUsingEagerSyncApproach(root: Folder, shouldIncludeDeletedItems: Bool) async throws {
        try await refreshUsingEagerSyncApproach(root: root, shouldIncludeDeletedItems: shouldIncludeDeletedItems, cancelToken: nil, onNodeRefreshed: { _ in })
    }
    
    func refreshUsingDirtyNodesApproach(
        root: Folder,
        progressClosure: @escaping (Int, Int) -> Void
    ) async throws {
        try await refreshUsingDirtyNodesApproach(root: root, resumingOnRetry: false, progressClosure: progressClosure)
    }
    
    func sendRefreshNotFinishedSentryEvent(root: Folder) async {
        await sendRefreshNotFinishedSentryEvent(root: root, error: nil)
    }
}

public final class RefreshingNodesService: RefreshingNodesServiceProtocol {
    
    private let downloader: Downloader
    private let coreEventManager: Tower.CoreEventLoopManager
    private let storage: StorageManager
    private let sessionVault: SessionVault
    
    private var cloudSlot: CloudSlotProtocol {
        downloader.cloudSlot
    }
    
    private var moc: NSManagedObjectContext {
        storage.backgroundContext
    }
    
    private static let shouldLogDebugInfo: Bool = Constants.buildType.isQaOrBelow
    
    init(downloader: Downloader,
         coreEventManager: Tower.CoreEventLoopManager,
         storage: StorageManager,
         sessionVault: SessionVault) {
        self.downloader = downloader
        self.coreEventManager = coreEventManager
        self.storage = storage
        self.sessionVault = sessionVault
    }
    
    public func hasDirtyNodes(root: Folder) async throws -> Bool {
        let shareID = await moc.perform { root.shareId }
        return try await storage.fetchDirtyNodesCount(share: shareID, moc: moc) > 0
    }
    
    public func refreshUsingEagerSyncApproach(
        root: Folder,
        shouldIncludeDeletedItems: Bool,
        cancelToken: CancelToken?,
        onNodeRefreshed: @MainActor @escaping (Int) -> Void
    ) async throws {
        
        var nodeCount = 0
        let enumeration: Downloader.Enumeration = { node in
            Log.debug("[Eager sync] Scanned node \(node.decryptedName)", domain: .syncing)
            nodeCount += 1
            Task { @MainActor [currentNodeCount = nodeCount] in
                onNodeRefreshed(currentNodeCount)
            }
        }
        
        _ = try await downloader.scanTrees(
            treesRootFolders: [root], enumeration: enumeration, cancelToken: cancelToken, shouldIncludeDeletedItems: shouldIncludeDeletedItems
        )
    }
    
    public func sendRefreshNotFinishedSentryEvent(root: Folder, error: Error?) async {
        let shareID = root.identifier.shareID
        // we add +1 because the count is reported excluding root, and we include root
        let allNodes = try? await storage.fetchNodesCount(of: shareID, moc: moc) + 1
        let dirtyNodes = try? await storage.fetchDirtyNodesCount(share: shareID, moc: moc)
        if let error {
            Log
                .error(
                    "CurrentDirtyNodesRefreshing failed",
                    error: error,
                    domain: .application,
                    context: LogContext(
                        "\(dirtyNodes.map(String.init) ?? "??") out of \(allNodes.map(String.init) ?? "??") were dirty."
                    )
                )
        } else {
            Log.error("PreviousDirtyNodesRefreshing failed", domain: .application, context: LogContext("\(dirtyNodes.map(String.init) ?? "??") out of \(allNodes.map(String.init) ?? "??") were dirty"))
        }
    }
    
    public func refreshUsingDirtyNodesApproach(
        root: Folder, resumingOnRetry: Bool, progressClosure: @escaping (Int, Int) -> Void
    ) async throws {
        // Nodes refreshing algorithm:
        // 0. Stop the events to not get the updates while the refresh is in-flight
        // 1. Mark all nodes as dirty OR fetch the currently dirty nodes (in case of retry)
        // 2. Start refreshing current dirty nodes
        
        // 0. Stop the events to not get the updates while the refresh is in-flight
        coreEventManager.suspend()
        
        do {
            let dirtyNodes: [NSManagedObjectID: Int64]
            let rootFolderIdentifier: NodeIdentifier
            if resumingOnRetry {
                // 1. fetch the currently dirty nodes (in case of retry)
                rootFolderIdentifier = await moc.perform { root.identifierWithinManagedObjectContext }
                let nodes = try await storage.fetchDirtyNodes(of: rootFolderIdentifier.shareID, moc: moc)
                dirtyNodes = await moc.perform {
                    Dictionary(uniqueKeysWithValues: nodes.map { ($0.objectID, $0.dirtyIndex) })
                }
                    
            } else {
                // 1. Mark all nodes as dirty
                (dirtyNodes, rootFolderIdentifier) = try await markAllNodesAsDirty(root: root, moc: moc)
            }
            let dirtyNodesCount = dirtyNodes.count
            let allNodesCount = try await storage.fetchNodesCount(of: rootFolderIdentifier.shareID, moc: moc) + 1 // +1 for root
            let startingCount = allNodesCount - dirtyNodesCount
            progressClosure(startingCount, allNodesCount)
            
            // 2. Start refreshing current dirty nodes
            let refreshingContext = RefreshingContext(
                dirtyNodes: dirtyNodes,
                refreshedNodes: [],
                permanentlyDeletedNodes: [],
                moc: moc,
                cloudSlot: cloudSlot,
                progressClosure: {
                    progressClosure(startingCount + dirtyNodesCount - $0, allNodesCount)
                }
            )
            try await Self.refreshNodes(rootFolderIdentifier: rootFolderIdentifier,
                                        refreshingContext: refreshingContext)
            try await refreshingContext.moc.perform {
                refreshingContext.permanentlyDeletedNodes.forEach {
                    let object = refreshingContext.moc.object(with: $0)
                    refreshingContext.moc.delete(object)
                }
                try refreshingContext.moc.save()
            }
            
            assert(refreshingContext.dirtyNodes.isEmpty)
            assert(dirtyNodesCount <= refreshingContext.refreshedNodes.count)
            
            progressClosure(allNodesCount, allNodesCount)
        } catch {
            await sendRefreshNotFinishedSentryEvent(root: root, error: error)
            throw error
        }
    }
    
    private func markAllNodesAsDirty(
        root: Folder, moc: NSManagedObjectContext
    ) async throws -> ([NSManagedObjectID: Int64], rootIdentifier: NodeIdentifier) {
        var dirtyNodes: [NSManagedObjectID: Int64] = [:]
        // by using a child context we can reset it afterwards, ensuring the updated objects are not kept in memory causing the spike
        try await Self.markNodeAsDirty(nodeID: root.objectID, dirtyNodes: &dirtyNodes, in: moc.childContext())
        let rootIdentifier = await moc.perform { root.identifierWithinManagedObjectContext }
        return (dirtyNodes, rootIdentifier)
    }
    
    private static func markNodeAsDirty(nodeID: NSManagedObjectID,
                                        dirtyNodes: inout [NSManagedObjectID: Int64],
                                        in moc: NSManagedObjectContext) async throws {
        var childrenIDs: [NSManagedObjectID] = []
        guard dirtyNodes[nodeID] == nil else { return }
        
        let dirtyIndex = Int64(dirtyNodes.count + 1)
        dirtyNodes[nodeID] = dirtyIndex
        
        try await moc.perform {
            guard let node = moc.object(with: nodeID) as? Node else {
                assertionFailure("should not happen")
                return
            }
            node.dirtyIndex = dirtyIndex
            try moc.save()

            if shouldLogDebugInfo {
                Log.debug("[Dirty nodes sync] Node \(nodeID) marked as dirty with index \(dirtyIndex)",
                          domain: .syncing)
            }

            if let folder = node as? Folder {
                childrenIDs = folder.children
                    .filter(\.shouldBeIncludedInRefresh)
                    .map { $0.objectID }
            }
            moc.reset()
        }
        
        try await childrenIDs.forEach {
            try await markNodeAsDirty(nodeID: $0, dirtyNodes: &dirtyNodes, in: moc)
        }
    }
    
    final class RefreshingContext {
        var dirtyNodes: [NSManagedObjectID: Int64]
        var refreshedNodes: Set<NSManagedObjectID>
        var permanentlyDeletedNodes: Set<NSManagedObjectID>
        let moc: NSManagedObjectContext
        let cloudSlot: CloudSlotProtocol
        let progressClosure: (Int) -> Void
        
        init(dirtyNodes: [NSManagedObjectID: Int64],
             refreshedNodes: Set<NSManagedObjectID>,
             permanentlyDeletedNodes: Set<NSManagedObjectID>,
             moc: NSManagedObjectContext,
             cloudSlot: CloudSlotProtocol,
             progressClosure: @escaping (Int) -> Void) {
            self.dirtyNodes = dirtyNodes
            self.refreshedNodes = refreshedNodes
            self.permanentlyDeletedNodes = permanentlyDeletedNodes
            self.moc = moc
            self.cloudSlot = cloudSlot
            self.progressClosure = progressClosure
        }
    }
    
    private static func refreshNodes(rootFolderIdentifier: NodeIdentifier?,
                                     refreshingContext ctx: RefreshingContext) async throws {
        guard let nodeID = ctx.dirtyNodes.min(by: { $0.value < $1.value })?.key else { return }
        let (nodeIdentifier, dirtyIndex, isFolder, shouldBeRefreshed) = ctx.moc.performAndWait {
            guard let node = ctx.moc.object(with: nodeID) as? Node else {
                assertionFailure("should never happen")
                return (NodeIdentifier("", "", ""), Int64(0), false, false)
            }
            return (node.identifierWithinManagedObjectContext, 
                    node.dirtyIndex,
                    node is Folder, 
                    node.shouldBeIncludedInRefresh)
        }
        guard shouldBeRefreshed, dirtyIndex != 0 else {
            ctx.dirtyNodes.removeValue(forKey: nodeID)
            ctx.refreshedNodes.insert(nodeID)
            return
        }
        
        guard isFolder else {
            return try await refreshFileNode(nodeManagedObjectID: nodeID,
                                             nodeIdentifier: nodeIdentifier,
                                             rootFolderIdentifier: rootFolderIdentifier,
                                             refreshingContext: ctx)
        }
        
        // special handling for root, which is the only previously known folder that needs refreshing its metadata explicitely
        // all the other previously known ones will have their metadata refreshed by their parents while they enumerate children
        // we don't handle the missing parent here because root has no parent by design
        if let rootFolderIdentifier, nodeIdentifier == rootFolderIdentifier {
            _ = try await withCheckedThrowingContinuation { continuation in
                ctx.cloudSlot.scanNode(rootFolderIdentifier, linkProcessingErrorTransformer: { $1 }, handler: { continuation.resume(with: $0) })
            }
        }
        
        try await refreshFolderNode(nodeManagedObjectID: nodeID,
                                    folderIdentifier: nodeIdentifier,
                                    rootFolderIdentifier: rootFolderIdentifier,
                                    refreshingContext: ctx)
    }
    
    private static func refreshFileNode(nodeManagedObjectID: NSManagedObjectID,
                                        nodeIdentifier: NodeIdentifier,
                                        rootFolderIdentifier: NodeIdentifier?,
                                        refreshingContext ctx: RefreshingContext) async throws {
        
        // File is marked as fresh if its metadata is available. The file metadata is usually fetched when enumerating its parent.
        // The exception is when parent is unknown to metadata DB (it was created during disconnection) so we need to fetch it explicitely.
        guard let refreshedNode = try await fetchNodeMetadataHandlingMissingParentError(nodeIdentifier: nodeIdentifier, refreshingContext: ctx)
        else {
            await ctx.moc.perform {
                let node = ctx.moc.object(with: nodeManagedObjectID)
                markNodeAsPermanentlyDeleted(node, refreshingContext: ctx)
            }
            return try await refreshNodes(rootFolderIdentifier: rootFolderIdentifier, refreshingContext: ctx)
        }
        
        try ctx.moc.performAndWait {
            let previousDirtyIndes = refreshedNode.dirtyIndex
            refreshedNode.dirtyIndex = 0
            try ctx.moc.save()
            let wasInserted = ctx.refreshedNodes.insert(refreshedNode.objectID).inserted
            assert(wasInserted)
            ctx.dirtyNodes.removeValue(forKey: refreshedNode.objectID)
            ctx.progressClosure(ctx.dirtyNodes.count)

            if shouldLogDebugInfo {
                Log.debug("[Dirty nodes sync] Refreshed file \(refreshedNode.objectID) with dirty index \(previousDirtyIndes), \(ctx.dirtyNodes.count) more dirty nodes to go",
                          domain: .syncing)
            }
        }
        
        return try await refreshNodes(rootFolderIdentifier: rootFolderIdentifier, refreshingContext: ctx)
    }
    
    private static func refreshFolderNode(nodeManagedObjectID: NSManagedObjectID,
                                          folderIdentifier: NodeIdentifier,
                                          rootFolderIdentifier: NodeIdentifier?,
                                          refreshingContext ctx: RefreshingContext) async throws {
        
        // Folder is marked as fresh if its metadata is available plus it has fetched all its children and saved their metadata.
        // The folder metadata is usually fetched when enumerating its parent. However, there are exceptions:
        // 1. Root folder, which is fresh if both its metadata and the children are fetched.
        //    This case is covered in special handling in `refreshNodes`.
        // 2. Folder whose parent is unknown to metadata DB (it was created during disconnection) so we need to fetch it explicitely.
        //    This case is covered in `fetchFolderNodeChildrenHandlingMissingParentError`, in the `HandlingMissingParentError` part.
        // 3. Folder whose parent was permanently deleted, so its metadata was never fetched alongside its children.
        //    We cover this case below, see `shouldRefreshMetadata`.

        let shouldRefreshMetadata = await ctx.moc.perform {
            guard let node = ctx.moc.object(with: nodeManagedObjectID) as? Node,
                  let parentObjectID = node.parentNode?.objectID
            else { return false }
            return ctx.permanentlyDeletedNodes.contains(parentObjectID)
        }
        
        if shouldRefreshMetadata {
            let folder = try await fetchNodeMetadataHandlingMissingParentError(nodeIdentifier: folderIdentifier, refreshingContext: ctx)
            guard folder != nil else {
                await ctx.moc.perform {
                    let node = ctx.moc.object(with: nodeManagedObjectID)
                    markNodeAsPermanentlyDeleted(node, refreshingContext: ctx)
                }
                return try await refreshNodes(rootFolderIdentifier: rootFolderIdentifier, refreshingContext: ctx)
            }
        }
        
        guard let (folder, refreshedChildren): (Node, [Node]) = try await fetchFolderNodeChildrenHandlingMissingParentError(
            folderIdentifier: folderIdentifier, refreshingContext: ctx
        ) else {
            await ctx.moc.perform {
                let node = ctx.moc.object(with: nodeManagedObjectID)
                markNodeAsPermanentlyDeleted(node, refreshingContext: ctx)
            }
            return try await refreshNodes(rootFolderIdentifier: rootFolderIdentifier, refreshingContext: ctx)
        }
        
        try await ctx.moc.perform {
            let refreshedFiles: [Node] = refreshedChildren.compactMap { $0 as? File }

            var refreshedObjectIDsWithDirtyIndex = ""
            if shouldLogDebugInfo {
                refreshedObjectIDsWithDirtyIndex = refreshedFiles.map {
                    "\($0.dirtyIndex)"
                }.joined(separator: ", ")
            }

            let folderDirtyIndex = folder.dirtyIndex
            let refreshedFilesWithParent = refreshedFiles.appending(folder)
            refreshedFilesWithParent.forEach { $0.dirtyIndex = 0 }
            try ctx.moc.save()
            refreshedFilesWithParent.forEach {
                let wasInserted = ctx.refreshedNodes.insert($0.objectID).inserted
                assert(wasInserted)
            }
            let refreshedNodesIdentifiers = refreshedFilesWithParent.map(\.objectID)
            refreshedNodesIdentifiers.forEach {
                ctx.dirtyNodes.removeValue(forKey: $0)
            }
            ctx.progressClosure(ctx.dirtyNodes.count)

            if shouldLogDebugInfo {
                Log.info("[Dirty nodes sync] Refreshed folder \(folder.objectID) with dirtyIndex \(folderDirtyIndex) alongside its \(refreshedFiles.count) children files with indexes: \(refreshedObjectIDsWithDirtyIndex). \(refreshedChildren.count - refreshedFiles.count) children folders to go. \(ctx.dirtyNodes.count) more dirty nodes to go",
                         domain: .syncing)
            }
        }
        
        try await refreshNodes(rootFolderIdentifier: rootFolderIdentifier, refreshingContext: ctx)
    }
    
    private static func fetchNodeMetadataHandlingMissingParentError(
        nodeIdentifier: NodeIdentifier, refreshingContext ctx: RefreshingContext
    ) async throws -> Node? {
        try await performHandlingMissingParentError(shareID: nodeIdentifier.shareID, refreshingContext: ctx) {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    ctx.cloudSlot.scanNode(nodeIdentifier,
                                           linkProcessingErrorTransformer: ErrorWithLink.init(link:error:),
                                           handler: { continuation.resume(with: $0) })
                }
            } catch {
                // identify the permanently deleted file error, we need to handle it gracefully
                guard let responseError = error as? ResponseError,
                      responseError.responseCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue
                else { throw error }
                return nil
            }
        }
    }
    
    private static func fetchFolderNodeChildrenHandlingMissingParentError(
        folderIdentifier: NodeIdentifier, refreshingContext ctx: RefreshingContext
    ) async throws -> (Node, [Node])? {
        do {
            return try await performHandlingMissingParentError(shareID: folderIdentifier.shareID, refreshingContext: ctx) {
                let (parent, children) = try await withCheckedThrowingContinuation { continuation in
                    fetchChildren(
                        folderIdentifier: folderIdentifier, cloudSlot: ctx.cloudSlot, pageToFetch: 0, pageSize: 150,
                        alreadyFetchedChildren: [], moc: ctx.moc, handler: { continuation.resume(with: $0) }
                    )
                }
                try await ensureChildrenHaveProperParent(parent: parent, children: children, refreshingContext: ctx)
                return (parent, children)
            }
        } catch {
            guard let responseError = error as? ResponseError,
                    responseError.responseCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue
            else { throw error }
            return nil
        }
        
    }
    
    private static func performHandlingMissingParentError<T>(
        shareID: String, refreshingContext ctx: RefreshingContext, operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            
            let (errorWithLink, parentLinkID) = try extractLinks(from: error)
            
            // the operation has failed because of missing parent node in the DB, let's fetch it!
            // we recurs into the same method for fetching parent because there might be a whole chain of missing parents
            _ = try await performHandlingMissingParentError(shareID: shareID, refreshingContext: ctx) {
                // VolumeID not used in macOS at the moment
                let parentIdentifier = NodeIdentifier(parentLinkID, shareID, "")
                guard let (parent, children) = try await fetchMetadataAndChildrenOfUnknownParentFolder(
                    nodeIdentifier: parentIdentifier, refreshingContext: ctx
                ) else {
                    // the node is not permanently deleted, but its parent is permanently deleted
                    // this should never happen, so let's return an original error
                    assertionFailure("The existing child must have the parent that's not permanently deleted")
                    // throwing back the original error
                    throw errorWithLink.error
                }
                
                return try ctx.moc.performAndWait {
                    // this is basically a sanity check
                    guard parent.id == parentLinkID,
                          let child = children.first(where: { node in node.id == errorWithLink.link.linkID })
                    else {
                        assertionFailure("The parent must have the child")
                        // throwing back the original error
                        throw errorWithLink.error
                    }
                    return child
                }
            }

            // once the parent is fetched, retry the original operation
            // this time, if it fails, it will not fail due to the missing parent anymore, because we've fetched it
            return try await operation()
        }
    }
    
    private static func markNodeAsPermanentlyDeleted(
        _ node: NSManagedObject, refreshingContext ctx: RefreshingContext
    ) {
        ctx.dirtyNodes.removeValue(forKey: node.objectID)
        var wasInserted = ctx.refreshedNodes.insert(node.objectID).inserted
        assert(wasInserted)
        wasInserted = ctx.permanentlyDeletedNodes.insert(node.objectID).inserted
        assert(wasInserted)
        ctx.progressClosure(ctx.dirtyNodes.count)
    }
    
    private static func extractLinks(from error: Error) throws -> (ErrorWithLink, String) {
        guard let errorWithLink = error as? ErrorWithLink else { throw error }
        let nsError = errorWithLink.error as NSError
        let code = CocoaError.Code(rawValue: nsError.code)
        let errorCodesIndicatingMissingParentLink: [CocoaError.Code] = [
            .coreData, .validationMultipleErrors, .validationMissingMandatoryProperty
        ]
        guard nsError.domain == NSCocoaErrorDomain,
              errorCodesIndicatingMissingParentLink.contains(code),
              let parentLinkID = errorWithLink.link.parentLinkID
        else { throw error }
        return (errorWithLink, parentLinkID)
    }
    
    private static func fetchMetadataAndChildrenOfUnknownParentFolder(
        nodeIdentifier: NodeIdentifier, refreshingContext ctx: RefreshingContext
    ) async throws -> (parent: Node, children: [Node])? {
        let node: Node
        do {
            node = try await withCheckedThrowingContinuation { continuation in
                ctx.cloudSlot.scanNode(nodeIdentifier,
                                       linkProcessingErrorTransformer: ErrorWithLink.init(link:error:),
                                       handler: { continuation.resume(with: $0) })
            }
        } catch {
            // identify the permanently deleted file error, we need to handle it gracefully
            guard let responseError = error as? ResponseError,
                    responseError.responseCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue
            else { throw error }
            return nil
        }
        guard let parent = node as? Folder else {
            assertionFailure("This should never happen, the parent is always a folder")
            return (parent: node, children: [])
        }
        
        let (_, children) = try await withCheckedThrowingContinuation { continuation in
            fetchChildren(folderIdentifier: nodeIdentifier, cloudSlot: ctx.cloudSlot, pageToFetch: 0, pageSize: 150,
                          alreadyFetchedChildren: [], moc: ctx.moc, handler: { continuation.resume(with: $0) })
        }
        try await ensureChildrenHaveProperParent(parent: parent, children: children, refreshingContext: ctx)
        
        return (parent, children)
    }
    
    private static func ensureChildrenHaveProperParent(
        parent: Folder, children: [Node], refreshingContext ctx: RefreshingContext
    ) async throws {
        let noLongerChildren = await ctx.moc.perform {
            let currentChildrenIdentifiers = children.map(\.identifierWithinManagedObjectContext)
            return parent.children
                .filter(\.shouldBeIncludedInRefresh)
                .filter { node in !currentChildrenIdentifiers.contains(node.identifierWithinManagedObjectContext) }
        }
        try await noLongerChildren.forEach { node in
            let nodeIdentifier = await ctx.moc.perform { node.identifierWithinManagedObjectContext }
            guard let refreshedNode = try await fetchNodeMetadataHandlingMissingParentError(nodeIdentifier: nodeIdentifier, refreshingContext: ctx)
            else {
                return await ctx.moc.perform {
                    markNodeAsPermanentlyDeleted(node, refreshingContext: ctx)
                }
            }

            // if node is a file and it was dirty, we can mark is as refreshed
            if refreshedNode is File, ctx.dirtyNodes[refreshedNode.objectID] != nil {
                try ctx.moc.performAndWait {
                    let previousDirtyIndes = refreshedNode.dirtyIndex
                    refreshedNode.dirtyIndex = 0
                    try ctx.moc.save()
                    let wasInserted = ctx.refreshedNodes.insert(refreshedNode.objectID).inserted
                    assert(wasInserted)
                    ctx.dirtyNodes.removeValue(forKey: refreshedNode.objectID)
                    ctx.progressClosure(ctx.dirtyNodes.count)

                    if shouldLogDebugInfo {
                        Log.debug("[Dirty nodes sync] Refreshed file \(refreshedNode.objectID) with dirty index \(previousDirtyIndes), \(ctx.dirtyNodes.count) more dirty nodes to go",
                                  domain: .syncing)
                    }
                }
            }
            if shouldLogDebugInfo {
                // sanity check
                await ctx.moc.perform {
                    guard refreshedNode.state != .deleted else { return }
                    assert(refreshedNode.parentNode?.identifierWithinManagedObjectContext != parent.identifierWithinManagedObjectContext)
                }
            }
        }        
    }
    
    // swiftlint:disable:next function_parameter_count
    private static func fetchChildren(folderIdentifier: NodeIdentifier,
                                      cloudSlot: CloudSlotProtocol,
                                      pageToFetch: Int,
                                      pageSize: Int,
                                      alreadyFetchedChildren: [Node],
                                      moc: NSManagedObjectContext,
                                      handler: @escaping (Result<(Folder, [Node]), Error>) -> Void) {
        cloudSlot.scanChildren(of: folderIdentifier, parameters: [.page(pageToFetch), .pageSize(pageSize)]) { resultChildren in
            switch resultChildren {
            case let .failure(error):
                handler(.failure(error))
                
            case let .success(nodes) where nodes.count < pageSize:
                do {
                    // this is last page
                    let folder: Folder? = try moc.performAndWait {
                        let fetchRequest = NSFetchRequest<Folder>(entityName: "Folder")
                        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                                             #keyPath(Folder.id), folderIdentifier.nodeID,
                                                             #keyPath(Folder.shareID), folderIdentifier.shareID)
                        guard let folder = try moc.fetch(fetchRequest).first else { return nil }
                        folder.isChildrenListFullyFetched = true
                        try moc.save()
                        return folder
                    }
                    guard let folder else {
                        assertionFailure("should not happen")
                        return
                    }
                    // return not `nodes` that we got for last page, but children from all pages
                    handler(.success((folder, alreadyFetchedChildren + nodes)))
                } catch {
                    handler(.failure(error))
                }
                
            case let .success(nodes):
                // this is not last page and need to request next one
                fetchChildren(folderIdentifier: folderIdentifier, cloudSlot: cloudSlot, pageToFetch: pageToFetch + 1,
                              pageSize: pageSize, alreadyFetchedChildren: alreadyFetchedChildren + nodes, moc: moc, handler: handler)
            }
        }
    }
}

private extension Node {
    var shouldBeIncludedInRefresh: Bool {
        UUID(uuidString: id) == nil
    }
}
