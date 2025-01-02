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

public class Downloader: NSObject, ProgressTrackerProvider {
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
        Log.info("Downloader.cancelAll, will cancell all downloads", domain: .downloader)
        self.queue.cancelAllOperations()
    }
    
    public func cancel(operationsOf identifiers: [NodeIdentifier]) {
        Log.info("Downloader.cancel(operationsOf:), will cancell downloads of \(identifiers)", domain: .downloader)
        self.queue.operations
            .compactMap { $0 as? DownloadFileOperation }
            .filter { operation in
                identifiers.contains { identifier in
                    operation.fileIdentifier.nodeID == identifier.nodeID
                        && operation.fileIdentifier.shareID == identifier.shareID
                }
            }
            .forEach { $0.cancel() }
    }

    func presentOperationFor(file: File) -> Operation? {
        self.queue.operations
            .filter { !$0.isCancelled }
            .compactMap({ $0 as? DownloadFileOperation })
            .first(where: { $0.fileIdentifier == file.identifier })
    }

    @discardableResult
    public func scheduleDownloadWithBackgroundSupport(cypherdataFor file: File,
                                                      completion: @escaping (Result<File, Error>) -> Void) -> Operation {
        let loggingCompletion: (Result<File, Error>) -> Void = { result in
            completion(
                result.mapError { error in
                    Log.error(DriveError(error), domain: .downloader)
                    return error
                }
            )
        }
        let operation = scheduleDownload(cypherdataFor: file, completion: loggingCompletion)
        BackgroundOperationsHandler.handle(operation, id: file.decryptedName)
        return operation
    }

    @discardableResult
    public func scheduleDownloadFileProvider(cypherdataFor file: File,
                                             completion: @escaping (Result<File, Error>) -> Void) -> Operation
    {
        scheduleDownload(cypherdataFor: file) { result in
            completion(
                result.mapError { error in
                    Log.error(DriveError(error), domain: .downloader)
                    return error
                }
            )
        }
    }

    @discardableResult
    public func scheduleDownloadOfflineAvailable(cypherdataFor file: File,
                                                 completion: @escaping (Result<File, Error>) -> Void) -> Operation {
        scheduleDownload(cypherdataFor: file) { result in
            completion(
                result.mapError { error in
                    Log.error(DriveError(error), domain: .downloader)
                    return error
                }
            )
        }
    }

    @discardableResult
    private func scheduleDownload(cypherdataFor file: File,
                                  completion: @escaping (Result<File, Error>) -> Void) -> Operation
    {
        if let presentOperation = self.presentOperationFor(file: file) {
            // this file is already in queue
            return presentOperation
        }

        let operation = DownloadFileOperation(file, cloudSlot: self.cloudSlot, endpointFactory: endpointFactory, storage: storage) { result in
            result.sendNotificationIfFailure(with: Self.downloadFail)
            completion(result)
        }
        self.queue.addOperation(operation)
        return operation
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
                          completion: @escaping (Result<[Node], Error>) -> Void) -> OperationWithProgress {
        let scanTree = ScanTreesOperation(folders: folders,
                                          cloudSlot: self.cloudSlot,
                                          storage: storage,
                                          enumeration: enumeration,
                                          endpointFactory: endpointFactory,
                                          completion: completion)
        self.queue.addOperation(scanTree)
        return scanTree
    }

    public func scanTrees(treesRootFolders folders: [Folder],
                          enumeration: @escaping Enumeration) async throws -> [Node] {
        try await withCheckedThrowingContinuation { continuation in
            let scanTree = ScanTreesOperation(folders: folders,
                                              cloudSlot: self.cloudSlot,
                                              storage: storage,
                                              enumeration: enumeration,
                                              endpointFactory: endpointFactory,
                                              completion: { result in
                switch result {
                case .success(let nodes):
                    continuation.resume(returning: nodes)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            })
            self.queue.addOperation(scanTree)
        }
    }

}

extension Downloader {
    public func downloadProcessesAndErrors() -> AnyPublisher<[ProgressTracker], Error> {
        self.progressPublisher(direction: .downstream)
            .setFailureType(to: Error.self)
            .merge(with: NotificationCenter.default.throwIfFailure(with: Self.downloadFail))
            .eraseToAnyPublisher()
    }
}
