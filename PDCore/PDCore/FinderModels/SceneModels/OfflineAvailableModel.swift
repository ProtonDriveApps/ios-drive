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

public final class OfflineAvailableModel: FinderModel, FinderErrorModel, NodesListing, DownloadsListing {
    // MARK: FinderModel
    public var folder: Folder?
    public func loadFromCache() {
        self.loadChildrenFromCache()
    }
    
    // MARK: NodesListing, DownloadsListing
    public var tower: Tower!
    public var childrenObserver: FetchedObjectsObserver<Node>
    public var sorting: SortPreference = .mimeAscending

    // MARK: FinderModel
    public var errorSubject = PassthroughSubject<Error, Never>()

    // MARK: others
    public init(tower: Tower) {
        self.tower = tower

        let children = tower.uiSlot!.subscribeToOfflineAvailable()
        self.childrenObserver = FetchedObjectsObserver(children)
    }
}

extension OfflineAvailableModel: ThumbnailLoader {
    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}
