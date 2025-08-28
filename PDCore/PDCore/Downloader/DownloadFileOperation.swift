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
import PDClient
import Combine

/// Accepts: File with short metadata
/// Works:
/// 1. makes API call to get full File metadata
/// 2. makes API call to get Active Revision metadata with a list of blocks
/// 3. creates a number of Operations to download all blocks to a temporary location
/// 4. adds local URLs of cyphertext to each Block managed object so Revision will be able to find it
/// Completion: error or URL of a cleatext file
final class DownloadFileOperation: SynchronousOperation, DownloadOperation {
    let fileIdentifier: NodeIdentifier
    private let endpointFactory: EndpointFactory
    private let storage: StorageManager
    private var completion: Completion?
    private weak var cloudSlot: CloudSlotProtocol!
    public var progress: Progress
    private lazy var internalQueue: OperationQueue = {
        let queue = OperationQueue(maxConcurrentOperation: Constants.maxConcurrentBlockDownloadsPerFile,
                                   isSuspended: true,
                                   name: "File Download - One File")
        return queue
    }()
    private let linkExpiredTime: TimeInterval
    private let expiredBuffer: TimeInterval
    private let batchSize: Int = 5
    private var expirationDate: Date = .distantPast
    private var cancellables = Set<AnyCancellable>()
    private var downloadTask: Task<(), Never>?
    /// does download complete?
    private var isComplete: Bool = false

    var identifier: AnyVolumeIdentifier {
        fileIdentifier.any()
    }

    init(
        _ file: File,
        cloudSlot: CloudSlotProtocol,
        endpointFactory: EndpointFactory,
        storage: StorageManager,
        linkExpiredTime: TimeInterval = 30 * 60 - 60, // Link in backend side expired in 30 mins, 1 min for buffer
        expiredBuffer: TimeInterval = 5 * 60, // Buffer before link expired
        chunkSize: Int = 5,
        completion: @escaping Completion
    ) {
        self.fileIdentifier = file.identifier
        self.cloudSlot = cloudSlot
        self.storage = storage
        self.endpointFactory = endpointFactory
        self.linkExpiredTime = linkExpiredTime
        self.expiredBuffer = expiredBuffer
        self.completion = completion
        self.progress = Progress(totalUnitCount: 0)
           
        super.init()
        
        if let urlForFingerprinting = URL(string: self.fileIdentifier.nodeID) {
            self.fingerprint(progress: progress, urlForFingerprinting)
        }
        
        if let revision = file.activeRevision,
           !revision.blocks.isEmpty,
           !revision.blocksAreValid() {
            Log.warning(
                "DownloadFileOperation.init, Invalid blocks are connected to revision, cleaning up, file: \(fileIdentifier)",
                domain: .downloader
            )
            file.activeRevision?.restoreAfterInvalidBlocksFound()
        }
    }
    
    override func start() {
        super.start()
        guard !self.isCancelled else { return }
        
        Task {
            do {
                let revision = try await initialRevision()
                guard !self.isCancelled else { return }
                await updateRevisionAndDownload(revision: revision)
            } catch {
                self.terminateOperationDueToError(error)
            }
        }
    }
    
    override func cancel() {
        Log.info("DownloadFileOperation.cancel, Cancel operation, file: \(fileIdentifier)", domain: .downloader)
        downloadTask?.cancel()
        self.internalQueue.isSuspended = true
        self.internalQueue.cancelAllOperations()
        self.completion = nil
        if !self.progress.isIndeterminate {
            self.progress.cancel()
        }
        super.cancel()
    }
    
    private func initialRevision() async throws -> Revision {
        do {
            Log.info("Starts to download file details for \(fileIdentifier)", domain: .downloader)
            let node = try await cloudSlot.scanNode(fileIdentifier, linkProcessingErrorTransformer: { $1 })
            let fileIdentifier = self.fileIdentifier
            return try await storage.backgroundContext.perform {
                guard let file = node as? File, let revision = file.activeRevision else {
                    let error = Errors.errorReadingMetadata
                    Log.error("Downloaded file details is in invalid state", error: error, domain: .downloader, context: LogContext("fileIdentifier: \(fileIdentifier)"))
                    throw error
                }
                return revision
            }
        } catch {
            Log
                .error(
                    "Couldn't fetch file details",
                    error: error,
                    domain: .downloader,
                    context: LogContext("fileIdentifier: \(fileIdentifier)")
                )
            throw error
        }
    }
    
    private func updateRevisionAndDownload(revision: Revision) async {
        downloadTask = Task {
            do {
                if self.isCancelled || Task.isCancelled { return }
                Log.info("Update revision and download blocks, file: \(fileIdentifier)", domain: .downloader)
                let updatedRevision = try await update(revision: revision)
                if self.isCancelled || Task.isCancelled { return }
                setupTimer(revision: revision)
                let isBlocksEmpty = await storage.backgroundContext.perform {
                    updatedRevision.blocks.isEmpty
                }
                if self.isCancelled || Task.isCancelled { return }
                if isBlocksEmpty {
                    try await finishOperationForEmpty(revision: updatedRevision)
                } else {
                    try await self.downloadBlocks(from: updatedRevision)
                }
            } catch {
                self.terminateOperationDueToError(error)
            }
        }
        await downloadTask?.value
    }
    
    private func setupTimer(revision: Revision) {
        expirationDate = Date().addingTimeInterval(linkExpiredTime)
        Timer
            .TimerPublisher(interval: linkExpiredTime, runLoop: .main, mode: .common)
            .autoconnect()
            .sink { [weak self, weak revision] _ in
                guard let self, let revision else { return }
                Log.info(
                    "Expiration timer for \(self.fileIdentifier) is fired",
                    domain: .downloader,
                    sendToSentryIfPossible: true
                )
                self.cancellables.removeAll()
                self.internalQueue.cancelAllOperations()
                self.downloadTask?.cancel()
                Task {
                    await self.updateRevisionAndDownload(revision: revision)
                }
            }
            .store(in: &cancellables)
        Log.info("Link for \(fileIdentifier) expired at \(expirationDate)", domain: .downloader)
    }
    
    private func update(revision: Revision) async throws -> Revision {
        guard !self.isCancelled, !Task.isCancelled else { return revision }
        let revisionIdentifier = await storage.backgroundContext.perform { revision.identifier }
        guard !self.isCancelled, !Task.isCancelled else { return revision }
        do {
            Log.info("Starts to scan revision for file: \(fileIdentifier), revision: \(revisionIdentifier)", domain: .downloader)
            let updatedRevision = try await cloudSlot.scanRevision(revisionIdentifier)
            return updatedRevision
        } catch {
            Log
                .error(
                    "Couldn't scan revision",
                    error: error,
                    domain: .downloader,
                    context: LogContext("File: \(fileIdentifier), revision: \(revisionIdentifier)")
                )
            throw error
        }
    }
    
    private func finishOperationForEmpty(revision: Revision) async throws {
        Log.info("Revision for \(fileIdentifier) is an empty file, creating empty file locally, revision: \(revision.identifier)", domain: .downloader)
        try await self.createEmptyFile(in: revision) // will call completion
        self.state = .finished
    }
    
    private func downloadBlocks(from revision: Revision) async throws {
        let blocksNeedToDownload = try await storage.backgroundContext.perform {
            let blocks = revision.blocks
                .compactMap { $0 as? DownloadBlock }
                .sorted(by: { $0.index < $1.index })
            guard !blocks.isEmpty else {
                let error = Errors.blockListNotAvailable
                Log
                    .error(
                        "Revision does not contain DownloadBlocks",
                        error: error,
                        domain: .downloader,
                        context: LogContext("File: \(self.fileIdentifier), revision: \(revision.identifier)")
                    )
                throw error
            }
            
            return blocks.filter { $0.localUrl == nil }
        }
        initializeProgressIfNeeded(blockCount: blocksNeedToDownload.count)
        
        let batches = blocksNeedToDownload.splitInGroups(of: batchSize)
        Log.info("Configure blocks download operations: \(blocksNeedToDownload.count), file: \(fileIdentifier)", domain: .downloader)
        let finishOperation = finishOperation(for: revision)
        if self.isCancelled || Task.isCancelled { return }
        downloadBlocks(in: batches, revision: revision, finishOperation: finishOperation)
    }
    
    private func initializeProgressIfNeeded(blockCount: Int) {
        if self.progress.totalUnitCount == 0 {
            self.progress.totalUnitCount = Int64(blockCount)
        }
    }
    
    private func finishOperation(for updatedRevision: Revision) -> BlockOperation {
        BlockOperation { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            Log.info("Blocks for \(self.fileIdentifier) are downloaded, prepare to save to coreData", domain: .downloader)
            
            // this may happen if the app is locked during download
            guard let moc = updatedRevision.managedObjectContext else {
                let error = Errors.mocDestroyedTooEarly
                Log
                    .error(
                        "Revision does not contain context",
                        error: error,
                        domain: .downloader,
                        context: LogContext("Revision: \(updatedRevision.identifier)")
                    )
                self.completion?(.failure(error))
                self.cancel()
                return
            }
            
            moc.performAndWait {
                do {
                    try moc.saveOrRollback()
                    Log.info("Blocks for \(self.fileIdentifier) are downloaded and saved", domain: .downloader)
                    self.isComplete = true
                    self.completion?(.success(updatedRevision.file))
                } catch {
                    self.terminateOperationDueToError(error)
                }
                self.state = .finished
            }
        }
    }
    
    private func downloadBlocks(in batches: [[DownloadBlock]], revision: Revision, finishOperation: BlockOperation) {
        if batches.isEmpty {
            internalQueue.addOperation(finishOperation)
            internalQueue.isSuspended = false
            return
        }
        for (idx, batch) in batches.enumerated() {
            if isComplete {
                Log.error("File is downloaded but download operation still running", error: nil, domain: .downloader)
                return
            }
            if self.isCancelled || Task.isCancelled { return }
            let isLastBatch = idx == batches.count - 1
            let timeout = expirationDate.timeIntervalSinceNow
            let operations = storage.backgroundContext.performAndWait {
                batch.compactMap { self.createOperationFor($0, timeout: timeout) }
            }
            guard operations.count == batch.count else {
                Log.debug("Terminate download, incorrect operations count: \(operations.count), batch count \(batch.count)", domain: .downloader)
                terminateOperationDueToError(Errors.unavailableDownloadURL)
                return
            }
            Log.info("Download \(operations.count) blocks for file \(fileIdentifier), timeout after \(timeout) seconds", domain: .downloader)
            operations.forEach { operation in
                self.progress.addChild(operation.progress, withPendingUnitCount: 1)
                if isLastBatch {
                    finishOperation.addDependency(operation)
                }
            }
            self.internalQueue.addOperations(operations, waitUntilFinished: false)
            if isLastBatch {
                self.internalQueue.addOperation(finishOperation)
            }
            self.internalQueue.isSuspended = false
            internalQueue.waitUntilAllOperationsAreFinished()
            if self.isCancelled || Task.isCancelled { return }
            if shouldRefreshLink() {
                
                Log.info(
                    "The blocks link for file \(fileIdentifier) are about to expire. Refresh them to avoid download failure.",
                    domain: .downloader,
                    sendToSentryIfPossible: true
                )
                // To prevent expiration timer fire at the same time
                cancellables.removeAll()
                Task {
                    await updateRevisionAndDownload(revision: revision)
                }
                return
            }
        }
    }
    
    private func shouldRefreshLink() -> Bool {
        Date() > expirationDate.addingTimeInterval(-1 * expiredBuffer)
    }
    
    private func createOperationFor(_ block: DownloadBlock, timeout: TimeInterval? = nil) -> DownloadBlockOperation? {
        guard let url = URL(string: block.downloadUrl) else {
            Log.error("Failed to create URL for \(block.downloadUrl)", error: nil, domain: .downloader)
            return nil
        }
        return DownloadBlockOperation(
            downloadTaskURL: url,
            endpointFactory: endpointFactory,
            completionHandler: { [weak self] result in
                guard let self = self else { return }
                guard !self.isCancelled else { return }
                switch result {
                case .success(let intermediateUrl):
                    block.managedObjectContext?.performAndWait { [fileIdentifier] in
                        do {
                            _ = try block.store(cypherfileFrom: intermediateUrl)
                            Log.info("Download and save \(block.index)th block for file: \(fileIdentifier)", domain: .downloader)
                        } catch let error {
                            Log
                                .error(
                                    "Saving block failed",
                                    error: error,
                                    domain: .downloader,
                                    context: LogContext("\(block.index)th block for file: \(fileIdentifier)")
                                )
                            self.terminateOperationDueToError(error)
                        }
                    }
                case .failure(let error):
                    Log.error(
                            "Downloading block failed",
                            error: error,
                            domain: .downloader,
                            context: LogContext("File: \(fileIdentifier)")
                        )
                    self.terminateOperationDueToError(error)
                }
            }
        )
    }
    
    private func createEmptyFile(in updatedRevision: Revision) async throws {
        if self.isCancelled || Task.isCancelled { return }
        let moc = storage.backgroundContext
        try await moc.perform {
            let emptyBlock: DownloadBlock = self.storage.new(
                with: "Locally-Generated-" + UUID().uuidString,
                by: #keyPath(DownloadBlock.downloadUrl),
                in: moc
            )
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
        }
    }
    
    private func terminateOperationDueToError(_ error: Error) {
        Log
            .error(
                "Terminated download file operation",
                error: error,
                domain: .downloader,
                context: LogContext("File: \(fileIdentifier)")
            )
        self.isComplete = true
        self.completion?(.failure(error))
        self.cancel()
    }
}

extension DownloadFileOperation {
    typealias Completion = (Result<File, Error>) -> Void
    enum Errors: Error {
        case errorReadingMetadata
        case blockListNotAvailable
        case mocDestroyedTooEarly
        case unavailableDownloadURL
    }
}
