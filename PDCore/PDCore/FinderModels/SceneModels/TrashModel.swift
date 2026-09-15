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
                .filter { $0.isToBeDeleted == false }
            return trash
        }
        .removeDuplicates(by: { old, new in
            old.map(\.genericIdentifier.id).sorted() == new.map(\.genericIdentifier.id).sorted()
        })
        .map { return self.sorting.sort($0) }
        .eraseToAnyPublisher()
    }
    
    public func switchSorting(_ sort: SortPreference) {
        self.tower.localSettings.nodesSortPreference = sort
    }
    
    public func loadChildrenFromCacheTrash() {
        self.childrenObserver.start()
    }
}

public final class TrashModel: FinderModel, TrashListing, NodesListing  {
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
            try await tower.cloudSlot.scanAllTrashed(volumeID: volumeID, moc: tower.storage.backgroundContext)
        }
        self.didFetchAllTrash = true
    }

    private var sdkTrashOperationsPerformer: SDKNodeOperationPerformer? {
        guard tower.featureFlags.isEnabled(flag: .driveiOSSDKTrashOperations) else { return nil }
        return tower.sdkObjects.nodeOperationPerformer
    }

    public func deleteTrashed(nodes: [NodeIdentifier]) async throws {
        if let performer = sdkTrashOperationsPerformer {
            Log.debug("Delete \(nodes.count) nodes via SDK", domain: .sdk)
            let (_, error) = try await performer.delete(nodes: nodes.map { $0.any() }).collectCompletion()
            if let error { throw error }
        } else {
            Log.debug("Delete \(nodes.count) nodes via legacy", domain: .nodeOperation)
            try await deleter.deletePerVolume(nodes)
        }
    }

    public func emptyTrash(nodes: [NodeIdentifier]) async throws {
        if let performer = sdkTrashOperationsPerformer {
            // Intentionally not injecting nodes
            // since semantically for empty trash, the function doesn't need to know which nodes are in the trash
            try await performer.emptyTrash()
        } else {
            try await trashCleaner.emptyTrashPerVolume(nodes)
        }
    }

    public func restoreTrashed(_ nodes: [NodeIdentifier]) async throws {
        if let performer = sdkTrashOperationsPerformer {
            Log.debug("Restore \(nodes.count) nodes via SDK", domain: .sdk)
            let (_, error) = try await performer.restore(nodes: nodes.map { $0.any() }).collectCompletion()
            if let error { throw error }
        } else {
            Log.debug("Restore \(nodes.count) nodes via legacy", domain: .nodeOperation)
            try await restorer.restoreVolume(nodes: nodes)
        }
        await MainActor.run {
            // To immediately refresh nodes' states
            // Special case for photos - we need to get update event to recreate CoreDataPhotoListing objects
            tower.forcePolling(volumeIDs: volumeIDs)
        }
    }
}
