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
import ProtonCoreNetworking

class ScanNodeOperation: SynchronousOperation, @unchecked Sendable {
    typealias Completion = (Result<[Node], Error>) -> Void

    enum Errors: Error, LocalizedError {
        case deallocatedDependency(nodeID: String)
        case unexpectedNodeType(nodeID: String)

        var errorDescription: String? {
            switch self {
            case .deallocatedDependency(let nodeID):
                "ScanNodeOperation dependency (cloudSlot/storage) was deallocated for node \(nodeID)"
            case .unexpectedNodeType(let nodeID):
                "ScanNodeOperation received non-Folder node for \(nodeID)"
            }
        }
    }

    private let nodeID: NodeIdentifier
    private let nodeObjectID: NSManagedObjectID?
    private weak var cloudSlot: CloudSlotProtocol?
    private weak var storage: StorageManager?
    private let shouldIncludeDeletedItems: Bool
    private let skipMetadataFetch: Bool
    private let skipFullyFetchedFolders: Bool
    private let resumePartialFoldersFromLastPage: Bool
    private let retryConfiguration: HttpClientResilience.Configuration
    private var completion: Completion?
    private var task: Task<Void, Never>?

    private let pageSize: Int

    init(_ nodeID: NodeIdentifier,
         objectID: NSManagedObjectID? = nil,
         cloudSlot: CloudSlotProtocol,
         storage: StorageManager,
         shouldIncludeDeletedItems: Bool = false,
         skipMetadataFetch: Bool = false,
         skipFullyFetchedFolders: Bool = false,
         resumePartialFoldersFromLastPage: Bool = false,
         pageSize: Int = 150,
         retryConfiguration: HttpClientResilience.Configuration = .forDriveAPICalls,
         completionHandler: @escaping Completion)
    {
        self.nodeID = nodeID
        self.nodeObjectID = objectID
        self.cloudSlot = cloudSlot
        self.storage = storage
        self.shouldIncludeDeletedItems = shouldIncludeDeletedItems
        self.skipMetadataFetch = skipMetadataFetch
        self.skipFullyFetchedFolders = skipFullyFetchedFolders
        self.resumePartialFoldersFromLastPage = resumePartialFoldersFromLastPage
        self.pageSize = pageSize
        self.retryConfiguration = retryConfiguration
        self.completion = completionHandler

        super.init()
    }

    override func cancel() {
        self.completion = nil
        self.task?.cancel()
        super.cancel()

        Log.info("Scan children operation cancelled for node \(self.nodeID.nodeID)", domain: .downloader)
    }

    override func start() {
        super.start()
        guard !self.isCancelled else { return }
        task = Task { [weak self] in
            guard let self else { return }
            self.finish(await self.scan())
        }
    }

    private func finish(_ result: Result<[Node], Error>) {
        // `completion` is nil after `cancel()`, so a cancelled run reports nothing — it only transitions
        // the operation to `.finished` so the queue can release it.
        self.completion?(result)
        self.state = .finished
    }

    private func scan() async -> Result<[Node], Error> {
        guard let cloudSlot, let storage else {
            Log.error("ScanNodeOperation: cloudSlot or storage was deallocated for node \(self.nodeID.nodeID)", domain: .downloader)
            return .failure(Errors.deallocatedDependency(nodeID: self.nodeID.nodeID))
        }
        let moc = storage.backgroundContext
        do {
            guard let folder = try await resolveFolder(cloudSlot: cloudSlot, moc: moc) else {
                Log.error("ScanNodeOperation received non-Folder node for \(self.nodeID.nodeID)", domain: .downloader)
                return .failure(Errors.unexpectedNodeType(nodeID: self.nodeID.nodeID))
            }
            let alreadyFetched = await moc.perform { folder.isChildrenListFullyFetched }
            if !(skipFullyFetchedFolders && alreadyFetched) {
                Log.info("Start fetching pages for node \(self.nodeID.nodeID)", domain: .networking)
                try await fetchAllChildren(of: folder, cloudSlot: cloudSlot, moc: moc)
            }
            let children = await moc.perform { Array(folder.children) }
            return .success(children)
        } catch {
            Log.error("scanNode failed", error: error, domain: .networking)
            return .failure(error)
        }
    }

    /// Resolves the folder to scan. A discovered child folder already has its metadata — the parent's
    /// `getFolderChildren` persisted its `Link` — so it is loaded locally and the redundant `getNode` is
    /// skipped. Tree roots (and any folder not yet stored) fetch their metadata via `scanNode`.
    private func resolveFolder(cloudSlot: CloudSlotProtocol, moc: NSManagedObjectContext) async throws -> Folder? {
        if skipMetadataFetch, let folder = await loadFolder(in: moc) {
            return folder
        }
        let node = try await withScanRetry {
            try await cloudSlot.scanNode(self.nodeID, linkProcessingErrorTransformer: { $1 }, moc: moc)
        }
        return node as? Folder
    }

    private func loadFolder(in moc: NSManagedObjectContext) async -> Folder? {
        await moc.perform {
            // Use the caller's objectID directly (no fetch) when available, otherwise look up by identifier.
            if let nodeObjectID = self.nodeObjectID,
               let folder = (try? moc.existingObject(with: nodeObjectID)) as? Folder {
                return folder
            }
            return Node.fetch(identifier: self.nodeID, allowSubclasses: true, in: moc) as? Folder
        }
    }

    // Similar functionality is also implemented in iOS app's NodesFetching model
    // usage of this technique is discouraged because recursive fetching is a heavy operation
    private func fetchAllChildren(of folder: Folder, cloudSlot: CloudSlotProtocol, moc: NSManagedObjectContext) async throws {
        // Resume from floor(storedChildren / pageSize) instead of page 0; the boundary page is re-fetched and
        // deduped, so no page is skipped. Assumes stable server-side ordering across runs.
        var page = resumePartialFoldersFromLastPage
            ? await moc.perform { folder.children.count / self.pageSize }
            : 0
        while !self.isCancelled {
            var params: [FolderChildrenEndpointParameters] = [
                .page(page),
                .pageSize(self.pageSize)
            ]
            if self.shouldIncludeDeletedItems {
                params.append(.showAll)
            }

            let nodes = try await withScanRetry {
                try await cloudSlot.scanChildren(of: self.nodeID, parameters: params, moc: moc)
            }

            guard nodes.count < self.pageSize else {
                // this is not last page and need to request next one
                Log.info("Fetched page #\(page) full (\(self.pageSize) nodes) for node \(self.nodeID.nodeID)", domain: .networking)
                page += 1
                continue
            }

            // this is last page
            Log.info("Fetched page #\(page) last (\(nodes.count) nodes) children for node \(self.nodeID.nodeID)", domain: .networking)
            await moc.perform {
                folder.isChildrenListFullyFetched = true
                try? moc.saveOrRollback()
            }
            return
        }
    }

    /// Runs `call`, retrying transient failures with exponential backoff via the shared resilience engine.
    /// No `RateLimitGate` is used here: the underlying `PDClient.Client` already handles 429s a layer down.
    private func withScanRetry<T>(_ call: @escaping () async throws -> T) async throws -> T {
        try await ScanRetry.perform(configuration: retryConfiguration, call)
    }
}
