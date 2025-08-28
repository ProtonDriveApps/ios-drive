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
                  completion: @escaping Completion) {
        self.node = node
        self.enumeration = enumeration
        self.cloudSlot = cloudSlot
        self.storage = storage
        self.endpointFactory = endpointFactory
        self.completion = completion

        super.init()
    }
    
    fileprivate var recursiveScanErrors: [Error] = []
    fileprivate var completion: Completion?
    fileprivate var node: Folder
    fileprivate var output: ReturnType!
    fileprivate var enumeration: Enumeration?
    fileprivate weak var cloudSlot: CloudSlotProtocol!
    fileprivate weak var storage: StorageManager!
    fileprivate let endpointFactory: EndpointFactory
    
    lazy var progress: Progress = {
        let progress = Progress(totalUnitCount: 0)
        // TODO: configure progress with child progresses
        return progress
    }()
    
    fileprivate lazy var finish: Operation = BlockOperation { [weak self] in
        guard let self = self, !self.isCancelled else { return }
        
        guard self.recursiveScanErrors.isEmpty else {
            self.completion?(.failure(Errors.compound(self.recursiveScanErrors)))
            return
        }
        self.node.managedObjectContext?.performAndWait {
            self.completion?(.success(self.output))
        }
        self.state = .finished
    }
    
    enum Errors: Error {
        case compound([Error])
    }
    
    override func cancel() {
        self.internalQueue.cancelAllOperations()
        self.enumeration = nil
        self.completion = nil
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

/// Downloads whole tree of Drive objects under a Folder, including ecnrypted blocks of active revisions of files
class DownloadTreeOperation: TreeParsingOperation<Folder>, @unchecked Sendable {
    
    override fileprivate func scanNodeAndChildrenOperation(of currentNode: Folder) -> Operation {
        self.output = currentNode
        self.enumeration?(currentNode)
        let operation = ScanNodeOperation(currentNode.identifier, cloudSlot: self.cloudSlot) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }
            
            switch result {
            case .failure(let error):
                self.recursiveScanErrors.append(error)
                
            case .success(let children):
                // files
                let downloadFiles = children.compactMap { $0 as? File }
                .filter { file -> Bool in
                    // need to download only files that are not downloaded yet
                    file.activeRevision?.blocksAreValid() != true
                }.map { file in
#if os(iOS)
                    DownloadFileOperation(file, cloudSlot: self.cloudSlot, endpointFactory: self.endpointFactory, storage: self.storage) { [weak self] in
                        // remember error or execute enumeration block
                        switch $0 {
                        case .success(let node):
                            self?.enumeration?(node)
                        case .failure(let error):
                            self?.recursiveScanErrors.append(error)
                        }
                    }
#else
                    /// Legacy for mac, can be removed after 2025 Feb, once macOS migrated to DDK
                    LegacyDownloadFileOperation(file, cloudSlot: self.cloudSlot, endpointFactory: self.endpointFactory, storage: self.storage) { [weak self] in
                        // remember error or execute enumeration block
                        switch $0 {
                        case .success(let node):
                            self?.enumeration?(node)
                        case .failure(let error):
                            self?.recursiveScanErrors.append(error)
                        }
                    }
#endif
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

class ScanTreesOperation: TreeParsingOperation<[Node]>, @unchecked Sendable {
    
    private let nodes: [Folder]
    private let shouldIncludeDeletedItems: Bool
    
    init(folders: [Folder],
         cloudSlot: CloudSlotProtocol,
         storage: StorageManager,
         enumeration: @escaping TreeParsingOperation.Enumeration,
         endpointFactory: EndpointFactory,
         shouldIncludeDeletedItems: Bool = true,
         completion: @escaping TreeParsingOperation<[Node]>.Completion) throws {
        guard let node = folders.first else {
            throw NSError(domain: "DownloadTreeOperation", code: -1, userInfo: [NSLocalizedDescriptionKey: "This operation must be called with at least a single node"])
        }
        self.nodes = folders
        self.shouldIncludeDeletedItems = shouldIncludeDeletedItems
        super.init(node: node, cloudSlot: cloudSlot, storage: storage, enumeration: enumeration, endpointFactory: endpointFactory, completion: completion)
        self.output = []
        internalQueue.maxConcurrentOperationCount = 6
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
        self.output.append(node)
        let operation = ScanNodeOperation(node.identifier,
                                          cloudSlot: self.cloudSlot,
                                          shouldIncludeDeletedItems: shouldIncludeDeletedItems) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }
            
            // this enumerates the folder
            self.enumeration?(node)
            
            switch result {
            case .failure(let error):
                self.progress.complete(units: 1)
                if let responseError = error as? ResponseError,
                   responseError.responseCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue {
                    /* ignore because this can happen for the permanently deleted file */
                } else {
                    self.recursiveScanErrors.append(error)
                }
                
            case .success(let children):
                children.forEach { self.output.append($0) }
                // only files are marked for enumeration, because for each folder we will perform an operation,
                // and folder is enumerated as part of this operation
                children.filter { $0 is File }.forEach { self.enumeration?($0) }
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
        let operation = ScanNodeOperation(currentNode.identifier, cloudSlot: self.cloudSlot) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }
            
            switch result {
            case .failure(let error):
                self.recursiveScanErrors.append(error)
                
            case .success(let children) where self.enumeration != nil:
                children.forEach(self.enumeration!)
                
            default: break
            }
        }
        
        return operation
    }
}
