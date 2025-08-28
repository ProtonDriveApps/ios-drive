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
import Combine
import PDClient

protocol DownloaderProtocol: AnyObject {
    func cancel(operationsOf identifiers: [NodeIdentifier])
    func cancel(operationsOf identifiers: [any VolumeIdentifiable])
}

public class Downloader: NSObject, ProgressTrackerProvider, DownloaderProtocol {
    public typealias Enumeration = (Node) -> Void
    private static let downloadFail: NSNotification.Name = .init("ch.protondrive.PDCore.downloadFail")
    
    public enum DownloadLocation {
        case temporary, offlineAvailable, oblivion
    }
    
    private var cancellables = Set<AnyCancellable>()

    public enum Errors: Error, LocalizedError {
        case unknownTypeOfShare
        case whileDownloading(File, Error)
        
        public var errorDescription: String? {
            "Could not download file"
        }
    }
    
    var cloudSlot: CloudSlotProtocol
    var storage: StorageManager
    let endpointFactory: EndpointFactory
    let successRateMonitor = DownloadSuccessRateMonitor()
    internal lazy var queue: OperationQueue = {
        let queue = OperationQueue(maxConcurrentOperation: Constants.maxConcurrentInflightFileDownloads,
                                   name: "File Download - All Files")
        return queue
    }()
    
    init(cloudSlot: CloudSlotProtocol, storage: StorageManager, endpointFactory: EndpointFactory) {
        self.cloudSlot = cloudSlot
        self.storage = storage
        self.endpointFactory = endpointFactory
    }
    
    public func cancelAll() {
        Log.info("Downloader.cancelAll, will cancel all downloads", domain: .downloader)
        successRateMonitor.cancelAll()
        self.queue.cancelAllOperations()
    }
    
    public func cancel(operationsOf identifiers: [NodeIdentifier]) {
        Log.info("Downloader.cancel(operationsOf:), will cancel downloads of \(identifiers)", domain: .downloader)
        successRateMonitor.cancel(identifiers: identifiers)

        queue.operations
            .compactMap { $0 as? DownloadOperation }
            .filter { operation in
                identifiers.contains { identifier in
                    operation.identifier.id == identifier.nodeID && operation.identifier.volumeID == identifier.volumeID
                }
            }
            .forEach { $0.cancel() }
    }

    public func cancel(operationsOf identifiers: [any VolumeIdentifiable]) {
        Log.info("Downloader.cancel(operationsOf:), will cancel downloads of \(identifiers)", domain: .downloader)
        successRateMonitor.cancel(identifiers: identifiers)
        queue.operations
            .compactMap { $0 as? DownloadOperation }
            .filter { operation in
                identifiers.contains { identifier in
                    operation.identifier.id == identifier.id && operation.identifier.volumeID == identifier.volumeID
                }
            }
            .forEach { $0.cancel() }
    }

    func presentOperationFor(file: File) -> Operation? {
        self.queue.operations
            .filter { !$0.isCancelled }
            .compactMap({ $0 as? DownloadOperation })
            .first(where: { $0.identifier == file.identifier.any() })
    }

    @discardableResult
    public func scheduleDownloadWithBackgroundSupport(cypherdataFor file: File,
                                                      useRefreshableDownloadOperation: Bool = false,
                                                      completion: @escaping (Result<File, Error>) -> Void) -> Operation {
        let loggingCompletion: (Result<File, Error>) -> Void = { [weak self, weak file] result in
            if let self, let file {
                self.reportDownloadResult(node: file, result: result)
            }
            completion(
                result.mapError { error in
                    Log.error(error: DriveError(error), domain: .downloader)
                    return error
                }
            )
        }
        let operation = scheduleDownload(
            cypherdataFor: file,
            useRefreshableDownloadOperation: useRefreshableDownloadOperation,
            completion: loggingCompletion
        )
        BackgroundOperationsHandler.handle(operation, id: file.decryptedName)
        return operation
    }

    @discardableResult
    public func scheduleDownloadFileProvider(cypherdataFor file: File,
                                             useRefreshableDownloadOperation: Bool = false,
                                             completion: @escaping (Result<File, Error>) -> Void) -> Operation
    {
        scheduleDownload(
            cypherdataFor: file,
            useRefreshableDownloadOperation: useRefreshableDownloadOperation
        ) { result in
            completion(
                result.mapError { error in
                    Log.error(error: DriveError(error), domain: .downloader)
                    return error
                }
            )
        }
    }

    @discardableResult
    public func scheduleDownloadOfflineAvailable(cypherdataFor file: File,
                                                 completion: @escaping (Result<File, Error>) -> Void) -> Operation {
        scheduleDownload(cypherdataFor: file) { [weak self, weak file] result in
            if let self, let file {
                self.reportDownloadResult(node: file, result: result)
            }
            completion(
                result.mapError { error in
                    Log.error(error: DriveError(error), domain: .downloader)
                    return error
                }
            )
        }
    }

    @discardableResult
    private func scheduleDownload(cypherdataFor file: File,
                                  useRefreshableDownloadOperation: Bool = false,
                                  completion: @escaping (Result<File, Error>) -> Void) -> Operation
    {
        if let presentOperation = self.presentOperationFor(file: file) {
            // this file is already in queue
            return presentOperation
        }
        let identifier = file.identifier
        if isMacOS() || !useRefreshableDownloadOperation {
            /// Legacy for mac, can be removed after 2025 Feb, once macOS migrated to DDK
            let operation = LegacyDownloadFileOperation(file, cloudSlot: self.cloudSlot, endpointFactory: endpointFactory, storage: storage) { [weak self] result in
                self?.clearUnavailableFileIfNeeded(identifier: identifier, error: result.error)
                result.sendNotificationIfFailure(with: Self.downloadFail)
                completion(result)
            }
            self.queue.addOperation(operation)
            return operation
        } else {
            let operation = DownloadFileOperation(file, cloudSlot: self.cloudSlot, endpointFactory: endpointFactory, storage: storage) { [weak self] result in
                self?.clearUnavailableFileIfNeeded(identifier: identifier, error: result.error)
                result.sendNotificationIfFailure(with: Self.downloadFail)
                completion(result)
            }
            self.queue.addOperation(operation)
            return operation
        }
    }

    @discardableResult
    private func downloadTree(of folder: Folder,
                              enumeration: @escaping Enumeration,
                              completion: @escaping (Result<Folder, Error>) -> Void) -> Operation
    {
        let downloadTree = DownloadTreeOperation(node: folder,
                                                 cloudSlot: self.cloudSlot,
                                                 storage: storage,
                                                 enumeration: enumeration,
                                                 endpointFactory: endpointFactory,
                                                 completion: completion)
        self.queue.addOperation(downloadTree)
        return downloadTree
    }
    
    @discardableResult
    public func scanChildren(of folder: Folder,
                             enumeration: @escaping Enumeration,
                             completion: @escaping (Result<Folder, Error>) -> Void) -> Operation
    {
        let scanChildren = ScanChildrenOperation(node: folder,
                                                 cloudSlot: self.cloudSlot,
                                                 storage: storage,
                                                 enumeration: enumeration,
                                                 endpointFactory: endpointFactory,
                                                 completion: completion)
        self.queue.addOperation(scanChildren)
        return scanChildren
    }
    
    @discardableResult
    public func scanTrees(treesRootFolders folders: [Folder],
                          enumeration: @escaping Enumeration,
                          cancelToken: CancelToken? = nil,
                          shouldIncludeDeletedItems: Bool = true,
                          completion: @escaping (Result<[Node], Error>) -> Void) throws -> OperationWithProgress {
        let scanTree = try ScanTreesOperation(folders: folders,
                                          cloudSlot: self.cloudSlot,
                                          storage: storage,
                                          enumeration: enumeration,
                                          endpointFactory: endpointFactory,
                                          shouldIncludeDeletedItems: shouldIncludeDeletedItems,
                                          completion: completion)
        cancelToken?.onCancel = { [weak scanTree] in
            scanTree?.cancel()
            completion(.failure(CocoaError(.userCancelled)))
        }
        self.queue.addOperation(scanTree)
        return scanTree
    }

    public func scanTrees(treesRootFolders folders: [Folder],
                          enumeration: @escaping Enumeration,
                          cancelToken: CancelToken? = nil,
                          shouldIncludeDeletedItems: Bool = true) async throws -> [Node] {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try scanTrees(treesRootFolders: folders,
                              enumeration: enumeration,
                              cancelToken: cancelToken,
                              shouldIncludeDeletedItems: shouldIncludeDeletedItems) { result in
                    switch result {
                    case .success(let nodes):
                        continuation.resume(returning: nodes)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            } catch let scanError {
                continuation.resume(throwing: scanError)
            }
        }
    }

    private func isMacOS() -> Bool {
#if os(macOS)
        return true
#else
        return false
#endif
    }
}

extension Downloader {
    public func downloadProcessesAndErrors() -> AnyPublisher<[ProgressTracker], Error> {
        self.progressPublisher(direction: .downstream)
            .setFailureType(to: Error.self)
            .merge(with: NotificationCenter.default.throwIfFailure(with: Self.downloadFail))
            .eraseToAnyPublisher()
    }

    public func downloadsPublisher() -> AnyPublisher<[AnyVolumeIdentifier], Never> {
        self.queue.publisher(for: \.operations)
            .compactMap { operations in
                operations.compactMap { ($0 as? DownloadOperation)?.identifier }
            }
            .eraseToAnyPublisher()
    }

    private func clearUnavailableFileIfNeeded(identifier: NodeIdentifier, error: Error?) {
        guard
            let error = error as? ResponseError,
            error.code == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue
        else { return }
        let context = storage.backgroundContext
        context.perform {
            guard let node = Node.fetch(identifier: identifier, allowSubclasses: true, in: context) else { return }
            context.delete(node)
            try? context.saveOrRollback()
        }
    }
}

extension Downloader {
    private func reportDownloadResult(node: Node, result: Result<File, Error>) {
        switch result {
        case .success:
            successRateMonitor.incrementSuccess(
                identifier: node.identifier,
                shareType: .from(node: node)
            )
        case .failure(let error):
            // Network issue is excluded
            if error.isNetworkIssueError { return }
            successRateMonitor.incrementFailure(
                identifier: node.identifier,
                shareType: .from(node: node)
            )
        }
    }
}
