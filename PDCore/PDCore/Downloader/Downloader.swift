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
import os.log
import Combine

public class Downloader: NSObject, ProgressTrackerProvider, LogObject {
    public typealias Enumeration = (Node) -> Void
    private static let downloadFail: NSNotification.Name = .init("ch.protondrive.PDCore.downloadFail")
    
    public enum DownloadLocation {
        case temporary, offlineAvailable, oblivion
    }
    
    public enum Errors: Error, LocalizedError {
        case unknownTypeOfShare
        case whileDownloading(File, Error)
        
        public var errorDescription: String? {
            "Could not download file"
        }
    }
    
    public static var osLog = OSLog.init(subsystem: "ch.protondrive.PDCore", category: "Downloader")
    private var cloudSlot: CloudSlot
    internal lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    init(cloudSlot: CloudSlot) {
        self.cloudSlot = cloudSlot
    }
    
    func cancelAll() {
        self.queue.cancelAllOperations()
    }
    
    public func cancel(operationsOf identifiers: [NodeIdentifier]) {
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
                    ConsoleLogger.shared?.log(DriveError(error, "Downloader"))
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
                    ConsoleLogger.shared?.log(DriveError(error, "Downloader"))
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
                    ConsoleLogger.shared?.log(DriveError(error, "Downloader"))
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

        let operation = DownloadFileOperation(file, cloudSlot: self.cloudSlot) { result in
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
                                                 enumeration: enumeration,
                                                 completion: completion)
        self.queue.addOperation(downloadTree)
        return downloadTree
    }
    
    @discardableResult
    public func scanChildren(of folder: Folder,
                             enumeration: @escaping Enumeration,
                             completion: @escaping (Result<Folder, Error>) -> Void) -> Operation
    {
        let downloadTree = ScanChildrenOperation(node: folder,
                                                 cloudSlot: self.cloudSlot,
                                                 enumeration: enumeration,
                                                 completion: completion)
        self.queue.addOperation(downloadTree)
        return downloadTree
    }
}

extension Downloader {
    public func downloadProcessesAndErrors() -> AnyPublisher<[ProgressTracker], Error> {
        self.progressPublisher()
        .setFailureType(to: Error.self)
        .merge(with: NotificationCenter.default.throwIfFailure(with: Self.downloadFail))
        .eraseToAnyPublisher()
    }
}
