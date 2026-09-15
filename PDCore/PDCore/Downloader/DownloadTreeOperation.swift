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

class TreeParsingOperation<ReturnType>: SynchronousOperation, OperationWithProgress, @unchecked Sendable {
    typealias Completion = (Result<ReturnType, Error>) -> Void
    typealias Enumeration = Downloader.Enumeration
    
    fileprivate lazy var internalQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.isSuspended = true
        return queue
    }()
    
    internal init(node: Folder,
                  cloudSlot: CloudSlotProtocol,
                  storage: StorageManager,
                  enumeration: @escaping Enumeration,
                  endpointFactory: EndpointFactory,
                  bytesCounterResource: BytesCounterResource,
                  completion: @escaping Completion) {
        self.node = node
        self.enumeration = enumeration
        self.cloudSlot = cloudSlot
        self.storage = storage
        self.endpointFactory = endpointFactory
        self.bytesCounterResource = bytesCounterResource
        self.completion = completion

        super.init()
    }
    
    fileprivate var completion: Completion?
    fileprivate var node: Folder
    fileprivate var output: ReturnType!
    fileprivate let enumeration: Enumeration?
    fileprivate weak var cloudSlot: CloudSlotProtocol!
    fileprivate weak var storage: StorageManager!
    fileprivate let endpointFactory: EndpointFactory
    fileprivate let bytesCounterResource: BytesCounterResource

    // Single terminal transition. Every terminal path (normal finish, error, cancellation) claims it
    // here, so the result is reported exactly once — replacing the previous design where the cancel
    // handler reported completion independently of the operation (two owners -> double resume -> crash).
    private var didComplete = Atomic(false)

    /// Atomically claims the terminal transition and hands back the completion for the single winner to
    /// invoke (or nil if it already terminated). The completion read+clear happens in the same atomic
    /// step, so a racing cancel can neither strand nor double-invoke it.
    private func claimCompletion() -> Completion? {
        var claimed: Completion?
        didComplete.mutate { alreadyCompleted in
            guard !alreadyCompleted else { return }
            alreadyCompleted = true
            claimed = self.completion
            self.completion = nil
        }
        return claimed
    }

    lazy var progress: Progress = {
        let progress = Progress(totalUnitCount: 0)
        // TODO: configure progress with child progresses
        return progress
    }()
    
    fileprivate lazy var finish: Operation = BlockOperation { [weak self] in
        guard let self = self, !self.isCancelled else { return }
        guard let completion = self.claimCompletion() else { return }
        // Reaching here means success: any failure already terminated the operation via `failFast`.
        self.node.managedObjectContext?.performAndWait {
            completion(.success(self.output))
        }
        self.state = .finished
    }
    
    /// Reports the first failure and stops the traversal: claims the single terminal, cancels remaining work,
    /// then reports the error. Concurrent failures race only on `claimCompletion`, so exactly one is reported.
    fileprivate func failFast(with error: Error) {
        guard let completion = claimCompletion() else { return }
        Log.error("Tree scan failed, stopping traversal", error: error, domain: .downloader)
        tearDownWork()
        completion(.failure(error))
        self.state = .finished
    }
    
    override func cancel() {
        tearDownWork()
        // A plain cancel is silent: it claims the terminal (so a late `finish` can't report) but does
        // not invoke completion. Callers awaiting a result cancel via `completeAsCancelled()` instead.
        _ = claimCompletion()
    }

    /// Cancels in-flight work and reports cancellation through the single terminal exactly once. Use this
    /// rather than `cancel()` when something is awaiting completion and must be resumed.
    func completeAsCancelled() {
        tearDownWork()
        guard let completion = claimCompletion() else { return }
        completion(.failure(CocoaError(.userCancelled)))
        self.state = .finished
    }

    private func tearDownWork() {
        self.internalQueue.cancelAllOperations()
        super.cancel()
    }
    
    override func start() {
        super.start()
        guard !self.isCancelled else { return }

        node.managedObjectContext?.performAndWait {
            let operation = self.scanNodeAndChildrenOperation(of: node)
            self.finish.addDependency(operation)
            self.internalQueue.addOperation(operation)
            self.internalQueue.addOperation(finish)
        }
        
        self.internalQueue.isSuspended = false
    }
    
    fileprivate func scanNodeAndChildrenOperation(of _: Folder) -> Operation {
        fatalError("Abstract method — must be overridden in the subclasses")
    }
}

#if os(iOS)

/// Downloads whole tree of Drive objects under a Folder, including ecnrypted blocks of active revisions of files
class DownloadTreeOperation: TreeParsingOperation<Folder>, @unchecked Sendable {
    
    override fileprivate func scanNodeAndChildrenOperation(of currentNode: Folder) -> Operation {
        self.output = currentNode
        self.enumeration?(currentNode)
        let operation = ScanNodeOperation(currentNode.identifier, cloudSlot: self.cloudSlot, storage: self.storage) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }
            
            switch result {
            case .failure(let error):
                self.failFast(with: error)
                
            case .success(let children):
                // files
                let downloadFiles = children.compactMap { $0 as? File }
                .filter { file -> Bool in
                    guard let revision = file.activeRevision else { return true }
                    // need to download only files that are not downloaded yet
                    return revision.isAvailableLocally() == false
                }.map { file in
                    DownloadFileOperation(
                        file,
                        cloudSlot: self.cloudSlot,
                        endpointFactory: self.endpointFactory,
                        storage: self.storage,
                        bytesCounterResource: self.bytesCounterResource
                    ) { [weak self] in
                        // remember error or execute enumeration block
                        switch $0 {
                        case .success(let node):
                            self?.enumeration?(node)
                        case .failure(let error):
                            self?.failFast(with: error)
                        }
                    }
                }
                downloadFiles.forEach(self.finish.addDependency)
                self.internalQueue.addOperations(downloadFiles, waitUntilFinished: false)
                
                // folders
                let scanSubfolders = children.compactMap { $0 as? Folder }.map(self.scanNodeAndChildrenOperation)
                scanSubfolders.forEach(self.finish.addDependency)
                self.internalQueue.addOperations(scanSubfolders, waitUntilFinished: false)
            }
        }
        
        return operation
    }
}

#endif

class ScanTreesOperation: TreeParsingOperation<[Node]>, @unchecked Sendable {
    
    private let nodes: [Folder]
    private let configuration: ScanConfiguration
    private let retryConfiguration: HttpClientResilience.Configuration
    private let nodesEnumeration: Downloader.NodesEnumeration
    // `output` is appended from up to 6 scan completion handlers running concurrently; serialize them.
    private let outputLock = NSLock()

    init(folders: [Folder],
         cloudSlot: CloudSlotProtocol,
         storage: StorageManager,
         nodesEnumeration: @escaping Downloader.NodesEnumeration,
         endpointFactory: EndpointFactory,
         configuration: ScanConfiguration = .default,
         retryConfiguration: HttpClientResilience.Configuration = .forDriveAPICalls,
         bytesCounterResource: BytesCounterResource,
         completion: @escaping TreeParsingOperation<[Node]>.Completion) throws {
        guard let node = folders.first else {
            throw NSError(domain: "DownloadTreeOperation", code: -1, userInfo: [NSLocalizedDescriptionKey: "This operation must be called with at least a single node"])
        }
        self.nodes = folders
        self.configuration = configuration
        self.retryConfiguration = retryConfiguration
        self.nodesEnumeration = nodesEnumeration
        // Nodes are reported in batches via `nodesEnumeration`, so the per-node callback is unused here.
        super.init(node: node, cloudSlot: cloudSlot, storage: storage, enumeration: { _ in }, endpointFactory: endpointFactory, bytesCounterResource: bytesCounterResource, completion: completion)
        self.output = []
        internalQueue.maxConcurrentOperationCount = 6
    }

    private func appendToOutput(_ nodes: [Node]) {
        outputLock.lock()
        defer { outputLock.unlock() }
        output.append(contentsOf: nodes)
    }

    override fileprivate func scanNodeAndChildrenOperation(of firstNode: Folder) -> Operation {
        let operationForHeadNode = operationForNode(firstNode)
        nodes
            .dropFirst()
            .map(operationForNode)
            .forEach { operation in
                self.finish.addDependency(operation)
                self.internalQueue.addOperation(operation)
            }
        return operationForHeadNode
    }
    
    private func operationForNode(_ node: Folder) -> Operation {
        if configuration.collectScannedNodes { self.appendToOutput([node]) }
        // Tree roots (the folders passed to scanTrees) fetch their own metadata; folders discovered as
        // children already have their Link from the parent's listing, so they skip the redundant getNode.
        let skipMetadataFetch = !nodes.contains { $0 === node }
        let operation = ScanNodeOperation(node.identifier,
                                          objectID: node.objectID,
                                          cloudSlot: self.cloudSlot,
                                          storage: self.storage,
                                          shouldIncludeDeletedItems: configuration.shouldIncludeDeletedItems,
                                          skipMetadataFetch: skipMetadataFetch,
                                          skipFullyFetchedFolders: configuration.skipFullyFetchedFolders,
                                          resumePartialFoldersFromLastPage: configuration.resumePartialFoldersFromLastPage,
                                          pageSize: configuration.pageSize,
                                          retryConfiguration: retryConfiguration) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }
            let moc = self.storage.backgroundContext

            // this enumerates the folder
            self.nodesEnumeration(moc, [node])
            
            switch result {
            case .failure(let error):
                self.progress.complete(units: 1)
                if let responseError = error as? ResponseError,
                   responseError.responseCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue {
                    /* ignore because this can happen for the permanently deleted file */
                } else {
                    self.failFast(with: error)
                }
                
            case .success(let children):
                if configuration.collectScannedNodes { self.appendToOutput(children) }
                // only files are marked for enumeration, because for each folder we will perform an operation,
                // and folder is enumerated as part of this operation
                self.nodesEnumeration(moc, children.filter { $0 is File })
                let scanSubfolders = children.compactMap { $0 as? Folder }.map(self.scanNodeAndChildrenOperation)
                scanSubfolders.forEach(self.finish.addDependency)
                self.progress.increaseTotalUnitsOfWork(by: scanSubfolders.count)
                self.progress.complete(units: 1) // complete for current one
                self.internalQueue.addOperations(scanSubfolders, waitUntilFinished: false)
            }
        }
        return operation
    }
}

class ScanChildrenOperation: TreeParsingOperation<Folder>, @unchecked Sendable {
    
    override fileprivate func scanNodeAndChildrenOperation(of currentNode: Folder) -> Operation {
        self.output = currentNode
        let operation = ScanNodeOperation(
            currentNode.identifier, cloudSlot: self.cloudSlot, storage: self.storage
        ) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }
            
            switch result {
            case .failure(let error):
                self.failFast(with: error)
                
            case .success(let children) where self.enumeration != nil:
                children.forEach(self.enumeration!)
                
            default: break
            }
        }
        
        return operation
    }
}
