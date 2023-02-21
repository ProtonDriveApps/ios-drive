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

/// Accepts: File with short metadata
/// Works:
/// 1. makes API call to get full File metadata
/// 2. makes API call to get Active Revision metadata with a list of blocks
/// 3. creates a number of Operations to download all blocks to a temporary location
/// 4. adds local URLs of cyphertext to each Block managed object so Revision will be able to find it
/// Completion: error or URL of a cleatext file
class DownloadFileOperation: SynchronousOperation, OperationWithProgress {
    typealias Completion = (Result<File, Error>) -> Void
    enum Errors: Error {
        case errorReadingMetadata
        case blockListNotAvailable
        case mocDestroyedTooEarly
    }
    
    private lazy var internalQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.isSuspended = true
        return queue
    }()
    
    override func start() {
        super.start()
        guard !self.isCancelled else { return }
        ConsoleLogger.shared?.log("Start operation", osLogType: Downloader.self)
        
        ConsoleLogger.shared?.log("Fetch full file details", osLogType: Downloader.self)
        self.cloudSlot.scanNode(fileIdentifier) { resultFile in
            guard !self.isCancelled else { return }
            switch resultFile {
            case .failure(let error):
                ConsoleLogger.shared?.log(error, osLogType: Downloader.self)
                self.completion?(.failure(error))
                self.cancel()
                
            case .success(let node):
                guard let file = node as? File, let revision = file.activeRevision else {
                    ConsoleLogger.shared?.log(Errors.errorReadingMetadata, osLogType: Downloader.self)
                    self.completion?(.failure(Errors.errorReadingMetadata))
                    self.cancel()
                    return
                }
            
                ConsoleLogger.shared?.log("Fetch full revision details", osLogType: Downloader.self)
                self.cloudSlot.scanRevision(revision.identifier) { resultRevision in
                    guard !self.isCancelled else { return }
                    switch resultRevision {
                    case .failure(let error):
                        ConsoleLogger.shared?.log(error, osLogType: Downloader.self)
                        self.completion?(.failure(error))
                        self.cancel()
                    
                    case .success(let updatedRevision) where updatedRevision.blocks.isEmpty:
                        ConsoleLogger.shared?.log("The revision is an empty file, creating empty file locally", osLogType: Downloader.self)
                        self.createEmptyFile(in: updatedRevision) // will call completion
                        self.state = .finished
                    
                    case .success(let updatedRevision):
                        var blocks = updatedRevision.blocks.compactMap { $0 as? DownloadBlock }
                        guard !blocks.isEmpty else {
                            ConsoleLogger.shared?.log(Errors.blockListNotAvailable, osLogType: Downloader.self)
                            self.completion?(.failure(Errors.blockListNotAvailable))
                            self.cancel()
                            return
                        }
                        
                        blocks.sort(by: { $0.index < $1.index })
                    
                        ConsoleLogger.shared?.log("Configure blocks download operations: \(blocks.count)", osLogType: Downloader.self)
                        let operations = blocks.map { self.createOperationFor($0) }
                        let finishOperation = BlockOperation { [weak self] in
                            guard let self = self, !self.isCancelled else { return }
                            
                            // this may happen if the app is locked during download
                            guard let moc = updatedRevision.managedObjectContext else {
                                let error = Errors.mocDestroyedTooEarly
                                ConsoleLogger.shared?.log(error, osLogType: Downloader.self)
                                self.completion?(.failure(error))
                                self.cancel()
                                return
                            }
                            
                            moc.performAndWait {
                                do {
                                    try moc.save()
                                    ConsoleLogger.shared?.log("Connected blocks to revision, revision to file", osLogType: Downloader.self)
                                    self.completion?(.success(updatedRevision.file))
                                } catch let error {
                                    ConsoleLogger.shared?.log(error, osLogType: Downloader.self)
                                    self.completion?(.failure(error))
                                    self.cancel()
                                }
                                self.state = .finished
                            }
                        }

                        self.progress.totalUnitCount = Int64(operations.count)
                        operations.forEach { operation in
                            self.progress.addChild(operation.progress, withPendingUnitCount: 1)
                            finishOperation.addDependency(operation)
                        }
                        
                        self.internalQueue.addOperations(operations, waitUntilFinished: false)
                        self.internalQueue.addOperation(finishOperation)
                        self.internalQueue.isSuspended = false
                    }
                }
            }
        }
    }
    
    override func cancel() {
        ConsoleLogger.shared?.log("Cancel operation", osLogType: Downloader.self)
        self.internalQueue.cancelAllOperations()
        self.completion = nil
        if !self.progress.isIndeterminate {
            self.progress.cancel()
        }
        super.cancel()
    }
    
    public var progress: Progress
    internal let fileIdentifier: NodeIdentifier
    private weak var cloudSlot: CloudSlot!
    private var completion: Completion?
    
    init(_ file: File, cloudSlot: CloudSlot, completion: @escaping Completion) {
        self.fileIdentifier = file.identifier
        self.cloudSlot = cloudSlot
        self.completion = completion
        self.progress = Progress(totalUnitCount: 0)
           
        super.init()
        
        if let urlForFingerprinting = URL(string: self.fileIdentifier.nodeID) {
            self.fingerprint(progress: progress, urlForFingerprinting)
        }
        
        if let revision = file.activeRevision, !revision.blocksAreValid() {
            ConsoleLogger.shared?.log("Invalid blocks are connected to revision, cleaning up", osLogType: Downloader.self)
            file.activeRevision?.restoreAfterInvalidBlocksFound()
        }
    }
    
    private func createOperationFor(_ block: DownloadBlock) -> DownloadBlockOperation {
        DownloadBlockOperation(downloadTaskURL: URL(string: block.downloadUrl)!) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let intermediateUrl):
                ConsoleLogger.shared?.log("Downloaded block", osLogType: Downloader.self)
                                
                block.managedObjectContext?.performAndWait {
                    do {
                        _ = try block.store(cypherfileFrom: intermediateUrl)
                    } catch let error {
                        ConsoleLogger.shared?.log(error, osLogType: Downloader.self)
                        self.completion?(.failure(error))
                        self.cancel()
                    }
                }
            case .failure(let error):
                ConsoleLogger.shared?.log(error, osLogType: Downloader.self)
                self.completion?(.failure(error))
                self.cancel()
            }
        }
    }
    
    private func createEmptyFile(in updatedRevision: Revision) {
        let moc = self.cloudSlot.storage.backgroundContext
        moc.performAndWait {
            do {
                let emptyBlock: DownloadBlock = self.cloudSlot.storage.new(with: "Locally-Generated-" + UUID().uuidString, by: #keyPath(DownloadBlock.downloadUrl), in: moc)
                emptyBlock.revision = updatedRevision
                emptyBlock.signatureEmail = updatedRevision.signatureAddress
                /*
                 Initializing a Block with empty Data is just to fullfill the Block initializer requirements
                 We will not verify or try to decrypt anything.
                 Conceptually in Proton Drive an empty file just revision with no Blocks,
                 but as the logic for the creation of URLs belongs up the Blocks we need to have a fake one.
                 */
                emptyBlock.sha256 = Data()
                updatedRevision.addToBlocks(emptyBlock)
                try emptyBlock.createEmptyFile() // will save moc
                self.completion?(.success(updatedRevision.file))
            } catch let error {
                ConsoleLogger.shared?.log(error, osLogType: Downloader.self)
                self.completion?(.failure(error))
                self.cancel()
            }
        }
    }
}
