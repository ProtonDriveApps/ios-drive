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

/// Downloads whole tree of Drive objects under a Folder, including ecnrypted blocks of active revisions of files
class DownloadTreeOperation: SynchronousOperation, OperationWithProgress {
    typealias Completion = (Result<Folder, Error>) -> Void
    typealias Enumeration = Downloader.Enumeration
    
    fileprivate lazy var internalQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.isSuspended = true
        return queue
    }()
    
    internal init(node: Folder, cloudSlot: CloudSlot, enumeration: @escaping Enumeration, completion: @escaping Completion) {
        self.node = node
        self.enumeration = enumeration
        self.cloudSlot = cloudSlot
        self.completion = completion

        super.init()
    }
    
    fileprivate var recursiveScanErrors: [Error] = []
    private var completion: Completion?
    private var node: Folder
    fileprivate var enumeration: Enumeration?
    fileprivate weak var cloudSlot: CloudSlot!
    
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
            self.completion?(.success(self.node))
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
    
    fileprivate func scanNodeAndChildrenOperation(of currentNode: Folder) -> Operation {
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
                    DownloadFileOperation(file, cloudSlot: self.cloudSlot) { [weak self] in
                        // remember error or execute enumeration block
                        switch $0 {
                        case .success(let node):
                            self?.enumeration?(node)
                        case .failure(let error):
                            self?.recursiveScanErrors.append(error)
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

class ScanChildrenOperation: DownloadTreeOperation {
    override func scanNodeAndChildrenOperation(of currentNode: Folder) -> Operation {
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
