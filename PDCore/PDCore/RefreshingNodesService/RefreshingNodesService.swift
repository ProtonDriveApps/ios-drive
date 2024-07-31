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

public final class RefreshingNodesService {
    
    private let downloader: Downloader
    private let coreEventManager: Tower.CoreEventLoopManager
    private let storage: StorageManager
    private let sessionVault: SessionVault
    
    private var cloudSlot: CloudSlot {
        downloader.cloudSlot
    }
    
    private var moc: NSManagedObjectContext {
        cloudSlot.moc
    }
    
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
        let shareID = await moc.perform { root.shareID }
        return try await storage.fetchDirtyNodesCount(share: shareID, moc: moc) > 0
    }
    
    public func refreshUsingEagerSyncApproach(root: Folder, evictItem: (NSFileProviderItemIdentifier) async throws -> Void) async throws {
        let enumeration: Downloader.Enumeration = { node in
            Log.debug("[Eager sync] Scanned node \(node.decryptedName)", domain: .syncing)
        }
        
        let nodes = try await downloader.scanTrees(treesRootFolders: [root], enumeration: enumeration)
        
        guard let moc = nodes.first?.moc else { throw Node.noMOC() }
        
        try await evictDeletedItems(from: nodes, in: moc, evictItem: evictItem)
    }
    
    private func evictDeletedItems(from nodes: [Node], in moc: NSManagedObjectContext,
                                   evictItem: (NSFileProviderItemIdentifier) async throws -> Void) async throws {
        let deletedNodesIdentifiers = await moc.perform {
            nodes.filter { $0.state == .deleted }.map { NSFileProviderItemIdentifier($0.identifierWithinManagedObjectContext.rawValue) }
        }
        
        try await deletedNodesIdentifiers
            .forEach { try await evictItem($0) }
    }
    
    public func sendRefreshNotFinishedSentryEvent(root: Folder, error: Error? = nil) async {
        let shareID = root.identifier.shareID
        // we add +1 because the count is reported excluding root, and we include root
        let allNodes = try? await storage.fetchNodesCount(of: shareID, moc: moc) + 1
        let dirtyNodes = try? await storage.fetchDirtyNodesCount(share: shareID, moc: moc)
        if let error {
            Log.error("CurrentDirtyNodesRefreshing failed when \(dirtyNodes.map(String.init) ?? "??") out of \(allNodes.map(String.init) ?? "??") were dirty. Error: \(error.localizedDescription)", domain: .application)
        } else {
            Log.error("PreviousDirtyNodesRefreshing failed when \(dirtyNodes.map(String.init) ?? "??") out of \(allNodes.map(String.init) ?? "??") were dirty", domain: .application)
        }
    }
    
    public func refreshUsingDirtyNodesApproach(root: Folder,
                                               resumingOnRetry: Bool = false,
                                               progressClosure: @escaping (Int, Int) -> Void,
                                               evictItem: (NSFileProviderItemIdentifier) async throws -> Void) async throws {
        // Nodes refreshing algorithm:
        // 0. Stop the events to not get the updates while the refresh is in-flight
        // 1. Mark all nodes as dirty OR fetch the currently dirty nodes (in case of retry)
        // 2. Start refreshing current dirty nodes
        // 3. Evict deleted items
        
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
                moc: moc,
                cloudSlot: cloudSlot,
                progressClosure: {
                    progressClosure(startingCount + dirtyNodesCount - $0, allNodesCount)
                }
            )
            try await Self.refreshNodes(rootFolderIdentifier: rootFolderIdentifier,
                                        refreshingContext: refreshingContext)
            
            assert(refreshingContext.dirtyNodes.isEmpty)
            assert(dirtyNodesCount <= refreshingContext.refreshedNodes.count)
            
            // 3. Evict deleted items
            let deletedNodes = try await refreshingContext.moc.perform {
                let fetchRequest = Node.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "%K == %d", 
                                                     #keyPath(Node.stateRaw), Node.State.deleted.rawValue)
                return try refreshingContext.moc.fetch(fetchRequest)
            }
            
            try await evictDeletedItems(from: deletedNodes, in: moc, evictItem: evictItem)
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
#if HAS_QA_FEATURES
            Log.debug("[Dirty nodes sync] Node \(nodeID) marked as dirty with index \(dirtyIndex)",
                      domain: .syncing)
#endif
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
        let moc: NSManagedObjectContext
        let cloudSlot: CloudSlot
        let progressClosure: (Int) -> Void
        
        init(dirtyNodes: [NSManagedObjectID: Int64],
             refreshedNodes: Set<NSManagedObjectID>,
             moc: NSManagedObjectContext,
             cloudSlot: CloudSlot,
             progressClosure: @escaping (Int) -> Void) {
            self.dirtyNodes = dirtyNodes
            self.refreshedNodes = refreshedNodes
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
                return (NodeIdentifier("", ""), Int64(0), false, false)
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
            return try await refreshFileNode(nodeIdentifier: nodeIdentifier,
                                             rootFolderIdentifier: rootFolderIdentifier,
                                             refreshingContext: ctx)
        }
        
        // special handling for root, which is the only previously known folder that needs refreshing its metadata explicitely
        // all the other previously known ones will have their metadata refreshed by their parents while they enumerate children
        // we don't handle the missing parent here because root has no parent by design
        if let rootFolderIdentifier, nodeIdentifier == rootFolderIdentifier {
            _ = try await withCheckedThrowingContinuation { continuation in
                ctx.cloudSlot.scanNode(nodeIdentifier, handler: continuation.resume(with:))
            }
        }
        
        try await refreshFolderNode(folderIdentifier: nodeIdentifier,
                                    rootFolderIdentifier: rootFolderIdentifier,
                                    refreshingContext: ctx)
    }
    
    private static func refreshFileNode(nodeIdentifier: NodeIdentifier,
                                        rootFolderIdentifier: NodeIdentifier?,
                                        refreshingContext ctx: RefreshingContext) async throws {
        
        // File is marked as fresh if its metadata is available. The file metadata is usually fetched when enumerating its parent.
        // The exception is when parent is unknown to metadata DB (it was created during disconnection) so we need to fetch it explicitely.
        
        let refreshedNode = try await fetchNodeMetadataHandlingMissingParentError(nodeIdentifier: nodeIdentifier, refreshingContext: ctx)
        try ctx.moc.performAndWait {
            let previousDirtyIndes = refreshedNode.dirtyIndex
            refreshedNode.dirtyIndex = 0
            try ctx.moc.save()
            let wasInserted = ctx.refreshedNodes.insert(refreshedNode.objectID).inserted
            assert(wasInserted)
            ctx.dirtyNodes.removeValue(forKey: refreshedNode.objectID)
            ctx.progressClosure(ctx.dirtyNodes.count)
#if HAS_QA_FEATURES
            Log.debug("[Dirty nodes sync] Refreshed file \(refreshedNode.objectID) with dirty index \(previousDirtyIndes), \(ctx.dirtyNodes.count) more dirty nodes to go",
                      domain: .syncing)
#endif
        }
        
        return try await refreshNodes(rootFolderIdentifier: rootFolderIdentifier,
                                      refreshingContext: ctx)
    }
    
    private static func refreshFolderNode(folderIdentifier: NodeIdentifier,
                                          rootFolderIdentifier: NodeIdentifier?,
                                          refreshingContext ctx: RefreshingContext) async throws {
        
        // Folder is marked as fresh if its metadata is available plus it has fetched all its children and saved their metadata.
        // The folder metadata is usually fetched when enumerating its parent. However, there are exceptions.
        // One of them is the root folder, which is fresh if both its metadata and the children are fetched.
        // The other one is the folder whose parent is unknown to metadata DB (it was created during disconnection) so we need to fetch it explicitely.
        
        let (folder, refreshedChildren) = try await fetchFolderNodeChildrenHandlingMissingParentError(
            folderIdentifier: folderIdentifier, refreshingContext: ctx
        )
        
        try ctx.moc.performAndWait {
            let refreshedFiles: [Node] = refreshedChildren.compactMap { $0 as? File }
#if HAS_QA_FEATURES
            let refreshedObjectIDsWithDirtyIndex = refreshedFiles.map {
                "\($0.dirtyIndex)"
            }.joined(separator: ", ")
#endif
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
#if HAS_QA_FEATURES
            Log.info("[Dirty nodes sync] Refreshed folder \(folder.objectID) with dirtyIndex \(folderDirtyIndex) alongside its \(refreshedFiles.count) children files with indexes: \(refreshedObjectIDsWithDirtyIndex). \(refreshedChildren.count - refreshedFiles.count) children folders to go. \(ctx.dirtyNodes.count) more dirty nodes to go",
                     domain: .syncing)
#endif
        }
        
        try await refreshNodes(rootFolderIdentifier: rootFolderIdentifier, refreshingContext: ctx)
    }
    
    private static func fetchNodeMetadataHandlingMissingParentError(
        nodeIdentifier: NodeIdentifier, refreshingContext ctx: RefreshingContext
    ) async throws -> Node {
        try await performHandlingMissingParentError(shareID: nodeIdentifier.shareID, refreshingContext: ctx) {
            try await withCheckedThrowingContinuation { continuation in
                ctx.cloudSlot.scanNode(nodeIdentifier,
                                   linkProcessingErrorTransformer: ErrorWithLink.init(link:error:),
                                   handler: continuation.resume(with:))
            }
        }
    }
    
    private static func fetchFolderNodeChildrenHandlingMissingParentError(
        folderIdentifier: NodeIdentifier, refreshingContext ctx: RefreshingContext
    ) async throws -> (Node, [Node]) {
        try await performHandlingMissingParentError(shareID: folderIdentifier.shareID, refreshingContext: ctx) {
            let (parent, children) = try await withCheckedThrowingContinuation { continuation in
                fetchChildren(
                    folderIdentifier: folderIdentifier, cloudSlot: ctx.cloudSlot, pageToFetch: 0, pageSize: 150,
                    alreadyFetchedChildren: [], moc: ctx.moc, handler: continuation.resume(with:)
                )
            }
            try await ensureChildrenHaveProperParent(parent: parent, children: children, refreshingContext: ctx)
            return (parent, children)
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
                let parentIdentifier = NodeIdentifier(parentLinkID, shareID)
                let (parent, children) = try await fetchNodeAndChildrenOfUnknownParent(
                    nodeIdentifier: parentIdentifier, refreshingContext: ctx
                )
                
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
    
    private static func fetchNodeAndChildrenOfUnknownParent(
        nodeIdentifier: NodeIdentifier, refreshingContext ctx: RefreshingContext
    ) async throws -> (parent: Node, children: [Node]) {
        let node = try await withCheckedThrowingContinuation { continuation in
            ctx.cloudSlot.scanNode(nodeIdentifier,
                                   linkProcessingErrorTransformer: ErrorWithLink.init(link:error:),
                                   handler: continuation.resume(with:))
        }
        
        guard let parent = node as? Folder else {
            assertionFailure("This should never happen, the parent is always a folder")
            return (parent: node, children: [])
        }
        
        let (_, children) = try await withCheckedThrowingContinuation { continuation in
            fetchChildren(folderIdentifier: nodeIdentifier, cloudSlot: ctx.cloudSlot, pageToFetch: 0, pageSize: 150,
                          alreadyFetchedChildren: [], moc: ctx.moc, handler: continuation.resume(with:))
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
            let refreshedNode = try await fetchNodeMetadataHandlingMissingParentError(nodeIdentifier: nodeIdentifier, refreshingContext: ctx)
            
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
#if HAS_QA_FEATURES
                    Log.debug("[Dirty nodes sync] Refreshed file \(refreshedNode.objectID) with dirty index \(previousDirtyIndes), \(ctx.dirtyNodes.count) more dirty nodes to go",
                              domain: .syncing)
#endif
                }
            }
        #if HAS_QA_FEATURES
            // sanity check
            await ctx.moc.perform {
                guard refreshedNode.state != .deleted else { return }
                assert(refreshedNode.parentLink?.identifierWithinManagedObjectContext != parent.identifierWithinManagedObjectContext)
            }
        #endif
        }        
    }
    
    // swiftlint:disable:next function_parameter_count
    private static func fetchChildren(folderIdentifier: NodeIdentifier,
                                      cloudSlot: CloudSlot,
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
