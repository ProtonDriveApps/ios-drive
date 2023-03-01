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

public final class SharedModel: FinderModel, NodesListing, DownloadsListing, NodesSorting {
    // MARK: FinderModel
    public var folder: Folder?
    public func loadFromCache() {
        self.loadChildrenFromCache()
    }
    
    // MARK: NodesListing, DownloadsListing
    public private(set) weak var tower: Tower!
    public private(set) var childrenObserver: FetchedObjectsObserver<Node>
    @Published public private(set) var sorting: SortPreference
    
    private let shareID: String
    
    // MARK: NodesSorting
    private var sortingObserver: AnyCancellable!
    public var sortingPublisher: Published<SortPreference>.Publisher {
        self.$sorting
    }
    
    // MARK: others
    public init(tower: Tower, shareID: String) {
        self.tower = tower
        self.shareID = shareID
        
        let children = tower.uiSlot!.subscribeToShared(share: shareID, sorting: tower.localSettings.nodesSortPreference)
        self.childrenObserver = FetchedObjectsObserver(children)
        
        self.sorting = self.tower.localSettings.nodesSortPreference
        
        self.sortingObserver = self.tower.localSettings.publisher(for: \.nodesSortPreference)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] sort in
            guard let self = self else { return }
            self.sorting = sort
            let children = tower.uiSlot!.subscribeToShared(share: shareID, sorting: sort)
            self.childrenObserver.inject(fetchedResultsController: children)
        }
    }
    
    public func fetchShared(at page: Int = 0, completion: @escaping (Result<Int, Error>) -> Void) {
        let pageSize = Constants.pageSizeForRefreshes
        tower.cloudSlot.scanAllShareURLs(ofMainShare: shareID, page: page, pageSize: pageSize) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let nodes):
                if nodes.count < pageSize {
                    self.tower.didFetchAllShareURLs = true
                    completion(.success(nodes.count))
                } else {
                    self.fetchShared(at: page + 1, completion: completion)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

extension SharedModel: ThumbnailLoader {
    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}
