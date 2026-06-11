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

/// Used for WorkingSet in FileProviders
public final class ActivityModel: FinderModel, NodesListing, UploadsListing, DownloadsListing {
    // MARK: FinderModel
    public let shareID: String
    public var folder: Folder?
    public func loadFromCache() {
        self.loadChildrenFromCache()
        self.loadUploadsFromCache()
    }
    
    // MARK: NodesListing, DownloadsListing
    public private(set) weak var tower: Tower!
    public private(set) var childrenObserver: FetchedObjectsObserver<Node>
    public private(set) var sorting: SortPreference
    private var context: NSManagedObjectContext?
    
    // MARK: UploadsListing
    public private(set) var childrenUploadingObserver: FetchedObjectsObserver<File>
    
    // MARK: others
    public init(tower: Tower, shareID: String) {
        self.shareID = shareID
        self.tower = tower
        self.sorting = SortPreference.default
        let children = tower.uiSlot!.subscribeToNodes(share: shareID, sorting: self.sorting)
        self.childrenObserver = FetchedObjectsObserver(children)
        
        let uploads = self.tower.storage.subscriptionToUploadingFiles()
        self.childrenUploadingObserver = FetchedObjectsObserver(uploads)
    }
    
    /// Constructor for background thead, uses fileSystemSlot
    public convenience init(tower: Tower) throws {
        let context = tower.storage.synchronousContextPool.acquire(for: .activityModel)
        let creatorAddresses = tower.sessionVault.addressIDs
        guard let share = tower.fileSystemSlot?.getMainShare(of: creatorAddresses, moc: context) else {
            throw FolderModel.Errors.noMainShareFound
        }
        let shareID = context.performAndWait { share.id }
        self.init(tower: tower, shareID: shareID)
        self.context = context
    }
    
    deinit {
        if context != nil, let tower {
            self.context = nil
            tower.storage.synchronousContextPool.relinquish(for: .activityModel)
        }
    }
}

extension ActivityModel: ThumbnailLoader {
    public func loadThumbnail(with id: Identifier) {
        return tower.loadThumbnail(with: id)
    }

    public func cancelThumbnailLoading(_ id: Identifier) {
        tower.cancelThumbnailLoading(id)
    }
}
