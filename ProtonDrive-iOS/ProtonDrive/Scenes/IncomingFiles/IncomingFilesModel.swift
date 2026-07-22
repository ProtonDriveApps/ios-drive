// Copyright (c) 2025 Proton AG
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
import Foundation
import PDClient
import PDCore

final class IncomingFilesModel: FinderModel, NodesListing, NodesFetching, NodesSorting {
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
    public let pageSize = PDCore.Constants.pageSizeForChildrenFetchAndEnumeration
    public var lastFetchedPage = 0

    init(tower: Tower, node: Folder, nodeID: NodeIdentifier) {
        self.tower = tower
        self.node = node
        self.currentNodeID = nodeID

        let children = tower.uiSlot!.subscribeToChildren(of: nodeID, sorting: tower.localSettings.nodesSortPreference)
        self.childrenObserver = FetchedObjectsObserver(children)

        self.sorting = self.tower.localSettings.nodesSortPreference

        self.sortingObserver = self.tower.localSettings
            .publisher(for: \.nodesSortPreference)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sort in
                guard let self = self else { return }
                self.sorting = sort
                let children = tower.uiSlot!.subscribeToChildren(of: self.node.identifier, sorting: sort)
                self.childrenObserver.inject(fetchedResultsController: children)
            }
    }

    func cancelDidTap() {
        PDFileManager.cleanShareTempFolder()
    }
}

extension IncomingFilesModel: ThumbnailLoader {
    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}

extension IncomingFilesModel: LayoutChanging {
    public var layout: LayoutPreference {
        tower.layout
    }

    public var layoutPublisher: AnyPublisher<LayoutPreference, Never> {
        tower.layoutPublisher
    }

    public func changeLayoutPreference(to newLayout: LayoutPreference) {
        tower.changeLayoutPreference(to: newLayout)
    }
}
