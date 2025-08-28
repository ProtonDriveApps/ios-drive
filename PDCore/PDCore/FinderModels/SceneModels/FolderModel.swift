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

import Combine
import CoreData
import PDClient

public final class FolderModel: FinderModel, FinderErrorModel, ThumbnailLoader, NodesListing, NodesFetching, UploadsListing, DownloadsListing, NodesSorting {
    public enum Errors: Error {
        case nodeIdDoesNotBelongToFolder(String)
        case nodeIdNotFound(String)
        case noFileSystemSlot
        case noMainShareFound
    }
    
    // MARK: FinderModel
    public var folder: Folder? { self.node }
    public func loadFromCache() {
        self.loadChildrenFromCache()
        self.loadUploadsFromCache()
    }
    
    // MARK: FinderErrorModel
    public let errorSubject = PassthroughSubject<Error, Never>()
    
    // MARK: NodesListing, DownloadsListing
    public private(set) weak var tower: Tower!
    public private(set) var childrenObserver: FetchedObjectsObserver<Node>
    @Published public private(set) var sorting: SortPreference
    
    // MARK: UploadsListing
    public private(set) var childrenUploadingObserver: FetchedObjectsObserver<File>
    
    // MARK: NodesSorting
    private var sortingObserver: AnyCancellable!
    public var sortingPublisher: Published<SortPreference>.Publisher {
        self.$sorting
    }
    
    // MARK: NodesFetching
    public let node: Folder // should be from main thread context
    public var currentNodeID: NodeIdentifier!
    public let pageSize = Constants.pageSizeForChildrenFetchAndEnumeration
    public var lastFetchedPage = 0
    
    // MARK: others
    public let userInfoController: UserInfoController?

    /// Constructor for main thread, uses UISlot for subscriptions
    public init(tower: Tower, node: Folder, nodeID: NodeIdentifier, userInfoController: UserInfoController? = nil) {
        self.tower = tower
        self.node = node
        self.userInfoController = userInfoController

        let children = tower.uiSlot!.subscribeToChildren(of: nodeID, sorting: tower.localSettings.nodesSortPreference)
        self.childrenObserver = FetchedObjectsObserver(children)
        
        let uploads = self.tower.storage.subscriptionToUploadingFiles()
        self.childrenUploadingObserver = FetchedObjectsObserver(uploads)
        
        self.currentNodeID = nodeID
        
        self.sorting = self.tower.localSettings.nodesSortPreference

        self.sortingObserver = self.tower.localSettings.publisher(for: \.nodesSortPreference)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] sort in
            guard let self = self else { return }
            self.sorting = sort
            let children = tower.uiSlot!.subscribeToChildren(of: self.node.identifier, sorting: sort)
            self.childrenObserver.inject(fetchedResultsController: children)
        }
    }

    /// Constructor for background thread, uses fileSystemSlot for subscriptions
    public init(tower: Tower, nodeID: NodeIdentifier, userInfoController: UserInfoController? = nil) throws {
        guard let fileSystemSlot = tower.fileSystemSlot else {
            throw Errors.noFileSystemSlot
        }

#if os(macOS)
        guard let node = fileSystemSlot.getNode(nodeID) ?? Self.fetchRemoteNode(tower: tower, nodeID: nodeID) else {
            throw Errors.nodeIdNotFound(nodeID.rawValue)
        }
#else
        guard let node = fileSystemSlot.getNode(nodeID) else {
            throw Errors.nodeIdNotFound(nodeID.rawValue)
        }
#endif

        guard let folder = node as? Folder else {
            throw Errors.nodeIdDoesNotBelongToFolder(nodeID.rawValue)
        }

        self.tower = tower
        self.node = folder
        self.userInfoController = userInfoController

        let children = tower.fileSystemSlot!.subscribeToChildren(of: nodeID)
        self.childrenObserver = FetchedObjectsObserver(children)
        
        let uploads = self.tower.storage.subscriptionToUploadingFiles()
        self.childrenUploadingObserver = FetchedObjectsObserver(uploads)
        
        self.currentNodeID = nodeID
        
        self.sorting = self.tower.localSettings.nodesSortPreference
    }

#if os(macOS)
    /// Synchronously return remote node.
    /// Needs to be synchronous because it will be indirectly called from `enumerateItems(for:startingAt:)`
    private static func fetchRemoteNode(tower: Tower, nodeID: NodeIdentifier) -> Node? {
        var result: Node?
        let semaphore = DispatchSemaphore(value: 0)

        assert(!Thread.isMainThread)
        Task {
            result = try await tower.cloudSlot.scanNode(nodeID, linkProcessingErrorTransformer: { $1 })
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }
#endif

    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}
