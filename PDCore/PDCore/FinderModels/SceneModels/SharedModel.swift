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

public final class SharedModel: FinderModel, FinderErrorModel, NodesListing, DownloadsListing, NodesSorting {
    // MARK: FinderModel
    public var folder: Folder?
    public func loadFromCache() {
        self.loadChildrenFromCache()
    }

    // MARK: NodesListing, DownloadsListing
    public private(set) weak var tower: Tower!
    public private(set) var childrenObserver: FetchedObjectsObserver<Node>
    @Published public private(set) var sorting: SortPreference

    private let volumeIds: [String]
    private let scanner: PublicLinkScanner

    // MARK: FinderErrorModel
    public var errorSubject = PassthroughSubject<Error, Never>()

    // MARK: NodesSorting
    private var sortingObserver: AnyCancellable!
    public var sortingPublisher: Published<SortPreference>.Publisher {
        self.$sorting
    }

    // MARK: others
    public init(tower: Tower, volumeIds: [String]) {
        self.tower = tower
        self.volumeIds = volumeIds
        self.scanner = PublicLinkScanner(client: tower.client, storage: tower.storage)
        let children = tower.uiSlot!.subscribeToPublicLinkShared(sorting: tower.localSettings.nodesSortPreference)
        self.childrenObserver = FetchedObjectsObserver(children)
        self.sorting = self.tower.localSettings.nodesSortPreference

        self.sortingObserver = self.tower.localSettings.publisher(for: \.nodesSortPreference)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sort in
                guard let self = self else { return }
                self.sorting = sort
                let children = tower.uiSlot!.subscribeToPublicLinkShared(sorting: tower.localSettings.nodesSortPreference)
                self.childrenObserver.inject(fetchedResultsController: children)
            }
    }

    public func fetchSharedByUrl() async throws {
        try await volumeIds.forEach { volumeId in
            try await scanner.scanAllShareURL(volumeID: volumeId)
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
