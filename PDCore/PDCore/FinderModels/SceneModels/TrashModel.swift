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
import CoreData

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
    private let volumeIDs: [String]
    private let restorer: TrashedNodeRestorer
    private let deleter: TrashedNodeDeleter
    private let trashCleaner: TrashCleaner

    @Published public private(set) var sorting: SortPreference

    public init(
        tower: Tower,
        restorer: TrashedNodeRestorer,
        deleter: TrashedNodeDeleter,
        trashCleaner: TrashCleaner
    ) {
        self.tower = tower
        self.restorer = restorer
        self.deleter = deleter
        self.trashCleaner = trashCleaner
        volumeIDs = tower.uiSlot.getOwnVolumeIds()
        assert(!volumeIDs.isEmpty, "A volume must always exist")
        Log.info("Initialized TrashModel with volumeIds: \(volumeIDs)", domain: .scenes)

        let children = tower.uiSlot!.subscribeToTrash(volumeIDs: volumeIDs)
        self.childrenObserver = FetchedObjectsObserver(children)
        
        self.sorting = self.tower.localSettings.nodesSortPreference
        
        self.sortingObserver = self.tower.localSettings.publisher(for: \.nodesSortPreference)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sort in
                guard let self = self else { return }
                self.sorting = sort
                let children = tower.uiSlot!.subscribeToTrash(volumeIDs: volumeIDs)
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
        try await volumeIDs.forEach { volumeID in
            try await tower.cloudSlot.scanAllTrashed(volumeID: volumeID)
        }
        self.didFetchAllTrash = true
    }

    public func deleteTrashed(nodes: [NodeIdentifier], isUsingVolumeBasedEndpoint: Bool) async throws {
        if isUsingVolumeBasedEndpoint {
            try await deleter.deletePerVolume(nodes)
        } else {
            try await deleter.delete(nodes)
        }
    }

    public func emptyTrash(nodes: [NodeIdentifier], isUsingVolumeBasedEndpoint: Bool) async throws {
        if isUsingVolumeBasedEndpoint {
            try await trashCleaner.emptyTrashPerVolume(nodes)
        } else {
            try await trashCleaner.emptyTrash(nodes)
        }
    }

    public func restoreTrashed(_ nodes: [NodeIdentifier], isUsingVolumeBasedEndpoint: Bool) async throws {
        if isUsingVolumeBasedEndpoint {
            try await restorer.restoreVolume(nodes: nodes)
        } else {
            try await restorer.restore(nodes)
        }
        await MainActor.run {
            // To immediately refresh nodes' states
            // Special case for photos - we need to get update event to recreate CoreDataPhotoListing objects
            tower.forcePolling(volumeIDs: volumeIDs)
        }
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
