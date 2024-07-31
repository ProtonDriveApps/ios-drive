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
import Foundation

// MARK: - New trash APIs
public protocol TrashListing: AnyObject {
    var tower: Tower! { get }
    var childrenObserver: FetchedObjectsObserver<Node> { get }
    var sorting: SortPreference { get }
}

extension TrashListing {
    public func childrenTrash() -> AnyPublisher<([Node]), Never> {
        self.childrenObserver.objectWillChange
        .map {
            let trash = self.childrenObserver.fetchedObjects
            return self.sorting.sort(trash)
        }
        .eraseToAnyPublisher()
    }
    
    public func switchSorting(_ sort: SortPreference) {
        self.tower.localSettings.nodesSortPreference = sort
    }
    
    public func loadChildrenFromCacheTrash() {
        self.childrenObserver.start()
    }
}

public final class TrashModel: FinderModel, TrashListing, NodesListing, ThumbnailLoader  {
    
    public let shareID: String
    private let volumeID: String
    
    @Published public private(set) var sorting: SortPreference

    public init(tower: Tower) {
        self.tower = tower
        self.volumeID = tower.uiSlot.getVolume()!.id // A volume must always exist
        self.shareID = tower.rootFolderIdentifier()!.shareID
        
        let children = tower.uiSlot!.subscribeToTrash()
        self.childrenObserver = FetchedObjectsObserver(children)
        
        self.sorting = self.tower.localSettings.nodesSortPreference
        
        self.sortingObserver = self.tower.localSettings.publisher(for: \.nodesSortPreference)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sort in
                guard let self = self else { return }
                self.sorting = sort
                let children = tower.uiSlot!.subscribeToTrash()
                self.childrenObserver.inject(fetchedResultsController: children)
            }
    }
    
    // MARK: FinderModel
    public var folder: Folder?
    public func loadFromCache() {
        self.loadChildrenFromCacheTrash()
    }
    
    // MARK: NodesSorting
    public var tower: Tower!
    private var sortingObserver: AnyCancellable!
    public var sortingPublisher: Published<SortPreference>.Publisher {
        self.$sorting
    }
    public let childrenObserver: FetchedObjectsObserver<Node>
    
    // unused by ViewModel, but can be used to prevent fetching of all nodes every time screen is opened
    public var didFetchAllTrash: Bool {
        get { tower.didFetchAllTrash }
        set { tower.didFetchAllTrash = newValue }
    }
    
    public func fetchTrash() async throws {
        try await tower.cloudSlot.scanAllTrashed(volumeID: volumeID)
        self.didFetchAllTrash = true
    }

    public func delete(nodes: [NodeIdentifier]) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            Log.info("Delete - Nodes", domain: .networking)
            self.tower.delete(nodes) {
                promise($0)
            }
        }
        .eraseToAnyPublisher()
    }

    public func emptyTrash(nodes: [NodeIdentifier]) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            Log.info("Empty Trash", domain: .networking)
            self.tower.emptyTrash(nodes) {
                promise($0)
            }
        }
        .eraseToAnyPublisher()
    }

    public func restoreFromTrash(nodes: [NodeIdentifier]) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            Log.info("Restore from Trash", domain: .networking)
            self.tower.restore(nodes) {
                promise($0)
            }
        }
        .eraseToAnyPublisher()
    }
}

extension TrashModel {
    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}
