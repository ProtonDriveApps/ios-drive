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

public final class MoveModel: FinderModel, NodesListing, NodesFetching, NodesSorting {
    // MARK: FinderModel
    public var folder: Folder? { self.node }
    public func loadFromCache() {
        self.loadChildrenFromCache()
    }
    
    // MARK: NodesListing
    public private(set) weak var tower: Tower!
    public private(set) var childrenObserver: FetchedObjectsObserver<Node>
    @Published public private(set) var sorting = SortPreference.default
    
    // MARK: NodesSorting
    private var sortingObserver: AnyCancellable!
    public var sortingPublisher: Published<SortPreference>.Publisher {
        self.$sorting
    }
    
    // MARK: NodesFetching
    public let node: Folder // should be from main thread context
    public var currentNodeID: NodeIdentifier!
    public let pageSize = Constants.pageSizeForRefreshes
    public var lastFetchedPage = 0
    
    // MARK: others
    private var moveCancellable: AnyCancellable?
    public var nodeIdsToMove: [NodeIdentifier]
    public var nodeToMoveParentId: NodeIdentifier
    public init(tower: Tower, node: Folder, nodeID: NodeIdentifier, nodesToMoveID: [NodeIdentifier], nodeToMoveParentID: NodeIdentifier) {
        self.tower = tower
        self.node = node
        self.currentNodeID = nodeID
        self.nodeIdsToMove = nodesToMoveID
        self.nodeToMoveParentId = nodeToMoveParentID
        
        let children = tower.uiSlot!.subscribeToChildren(of: nodeID, sorting: tower.localSettings.nodesSortPreference)
        self.childrenObserver = FetchedObjectsObserver(children)
        
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
}

extension MoveModel {
    public func moveHere(handler: @escaping (Result<[NodeIdentifier], Error>) -> Void) {
        // 1. create collection of Tower.move(nodeID:under:) futures
        // 2. run them one by one
        // 3. delete nodeID after each successfull one, stop in case of error
        // 4. call handler when all done
        let nodeIds = self.nodeIdsToMove
        let node = self.node
        
        self.moveCancellable?.cancel()
        self.moveCancellable = self.nodeIdsToMove.compactMap { nodeID in
            Deferred {
                Future<NodeIdentifier, Error> { [weak self] promise in
                    Log.info("Start move call: \(nodeID)", domain: .networking)
                    self?.tower.move(nodeID: nodeID, under: node) { result in
                        Log.info("Finish move call: \(nodeID)", domain: .networking)
                        switch result {
                        case .success(let node):
                            promise(.success(node.identifier))
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    }
                }
            }
        }
        .serialize()?
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { completion in
            Log.info("Finished moving nodes", domain: .networking)
            switch completion {
            case .finished:
                handler(.success(nodeIds))
            case let .failure(error):
                handler(.failure(error))
            }
        }, receiveValue: { [weak self] nodeIdentifier in
            self?.nodeIdsToMove = nodeIds.filter { $0.nodeID != nodeIdentifier.nodeID }
            Log.info("Moved node: \(node.identifier)", domain: .networking)
        })
    }
}

extension MoveModel: ThumbnailLoader {
    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}
