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
import CoreData
import PDClient

public protocol DownloaderProtocol: AnyObject {
    func cancelAll()
    func cancel(operationsOf identifiers: [any VolumeIdentifiable])
}

public protocol TrackableDownloader {
#if os(iOS)
    @MainActor
    var isActivePublisher: AnyPublisher<Bool, Never> { get }
    @MainActor
    var bytesCounterResource: BytesCounterResource { get }
#endif
}

/// Options for `Downloader.scanTrees`. Defaults match prior behavior: include deleted items, collect
/// scanned nodes, no resume optimizations, 150-item pages.
public struct ScanConfiguration {
    public var shouldIncludeDeletedItems: Bool
    public var collectScannedNodes: Bool
    public var skipFullyFetchedFolders: Bool
    public var resumePartialFoldersFromLastPage: Bool
    public var pageSize: Int

    public init(shouldIncludeDeletedItems: Bool = true,
                collectScannedNodes: Bool = true,
                skipFullyFetchedFolders: Bool = false,
                resumePartialFoldersFromLastPage: Bool = false,
                pageSize: Int = 150) {
        self.shouldIncludeDeletedItems = shouldIncludeDeletedItems
        self.collectScannedNodes = collectScannedNodes
        self.skipFullyFetchedFolders = skipFullyFetchedFolders
        self.resumePartialFoldersFromLastPage = resumePartialFoldersFromLastPage
        self.pageSize = pageSize
    }

    public static let `default` = ScanConfiguration()
}

public class Downloader: NSObject {
    public typealias Enumeration = (Node) -> Void
    /// Reports a batch of nodes (a folder's sibling files, or a single folder) with the context to read them in.
    public typealias NodesEnumeration = (NSManagedObjectContext, [Node]) -> Void
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
    private let endpointFactory: EndpointFactory
    public let bytesCounterResource: BytesCounterResource
    private let scanRetryConfiguration: HttpClientResilience.Configuration

    lazy var queue: OperationQueue = {
        let queue = OperationQueue(maxConcurrentOperation: Constants.maxConcurrentInflightFileDownloads,
                                   name: "File Download - All Files")
        return queue
    }()

    init(
        cloudSlot: CloudSlotProtocol,
        storage: StorageManager,
        endpointFactory: EndpointFactory,
        bytesCounterResource: BytesCounterResource,
        scanRetryConfiguration: HttpClientResilience.Configuration = .forDriveAPICalls
    ) {
        self.cloudSlot = cloudSlot
        self.storage = storage
        self.endpointFactory = endpointFactory
        self.bytesCounterResource = bytesCounterResource
        self.scanRetryConfiguration = scanRetryConfiguration
    }

    public func cancelAll() {
        Log.info("Downloader.cancelAll, will cancel all downloads", domain: .downloader)
        self.queue.cancelAllOperations()
    }

    public func cancel(operationsOf identifiers: [any VolumeIdentifiable]) {
        Log.info("Downloader.cancel(operationsOf:), will cancel downloads of \(identifiers)", domain: .downloader)
        queue.operations
            .compactMap { $0 as? DownloadOperation }
            .filter { operation in
                identifiers.contains { identifier in
                    operation.identifier.id == identifier.id && operation.identifier.volumeID == identifier.volumeID
                }
            }
            .forEach { $0.cancel() }
    }
    
    @discardableResult
    public func scanChildren(of folder: Folder,
                             enumeration: @escaping Enumeration,
                             completion: @escaping (Result<Folder, Error>) -> Void) -> Operation
    {
        Log.info("Downloader - scan \(folder.identifier.id)", domain: .downloader)
        let scanChildren = ScanChildrenOperation(
            node: folder,
            cloudSlot: self.cloudSlot,
            storage: storage,
            enumeration: enumeration,
            endpointFactory: endpointFactory,
            bytesCounterResource: bytesCounterResource,
            completion: completion
        )
        self.queue.addOperation(scanChildren)
        return scanChildren
    }
    
    @discardableResult
    public func scanTrees(treesRootFolders folders: [Folder],
                          enumeration: @escaping NodesEnumeration,
                          cancelToken: CancelToken? = nil,
                          configuration: ScanConfiguration = .default,
                          completion: @escaping (Result<[Node], Error>) -> Void) throws -> OperationWithProgress {
        let scanTree = try ScanTreesOperation(
            folders: folders,
            cloudSlot: self.cloudSlot,
            storage: storage,
            nodesEnumeration: enumeration,
            endpointFactory: endpointFactory,
            configuration: configuration,
            retryConfiguration: scanRetryConfiguration,
            bytesCounterResource: bytesCounterResource,
            completion: completion
        )
        cancelToken?.onCancel = { [weak scanTree] in
            scanTree?.completeAsCancelled()
        }
        self.queue.addOperation(scanTree)
        return scanTree
    }

    public func scanTrees(treesRootFolders folders: [Folder],
                          enumeration: @escaping NodesEnumeration,
                          cancelToken: CancelToken? = nil,
                          configuration: ScanConfiguration = .default) async throws -> [Node] {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try scanTrees(treesRootFolders: folders,
                              enumeration: enumeration,
                              cancelToken: cancelToken,
                              configuration: configuration) { result in
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
}

#if os(iOS)

extension Downloader {
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
#endif
