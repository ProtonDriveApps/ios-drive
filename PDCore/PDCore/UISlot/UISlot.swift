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
import CoreData

public class UISlot {
    public init(storage: StorageManager) {
        self.storage = storage
    }
    
    private(set) var storage: StorageManager
    private var moc: NSManagedObjectContext {
        self.storage.mainContext
    }
    
    public func performInBackground(_ closure: @escaping (NSManagedObjectContext) -> Void) {
        self.storage.backgroundContext.perform {
            closure(self.storage.backgroundContext)
        }
    }

    // MARK: - GET FROM DB
    
    public func getVolumeId() -> String? {
        try? self.storage.getVolumeIDs(in: moc).myVolume
    }
    
    public func getRoots(handler: @escaping (Result<[Share], Error>) -> Void) {
        do {
            let result = try self.storage.fetchShares(moc: self.moc)
            handler(.success(result))
        } catch let error {
            handler(.failure(error))
        }
    }
    
    public func getChildren(of parentID: NodeIdentifier, sorting: SortPreference, handler: @escaping (Result<[Node], Error>) -> Void) {
        do {
            let result = try self.storage.fetchChildren(of: parentID.nodeID, share: parentID.shareID, sorting: sorting, moc: self.moc)
            handler(.success(result))
        } catch let error {
            handler(.failure(error))
        }
    }
    
    public func getNode(_ id: NodeIdentifier, handler: @escaping (Result<Node?, Error>) -> Void) {
        let result = self.storage.fetchNode(id: id, moc: self.moc)
        handler(.success(result))
    }
    
    // MARK: - SUBSCRIBE TO DB CHANGES
    
    /// Subscribe to updates about children of a folder
    public func subscribeToRoots() -> NSFetchedResultsController<Share> {
        self.storage.subscriptionToRoots(moc: self.moc)
    }
    
    public func subscribeToNodes(share shareID: String, sorting: SortPreference) -> NSFetchedResultsController<Node> {
        self.storage.subscriptionToNodes(share: shareID, sorting: sorting, moc: self.moc)
    }
    
    public func subscribeToChildren(of parentID: NodeIdentifier, sorting: SortPreference) -> NSFetchedResultsController<Node> {
        self.storage.subscriptionToChildren(ofNode: parentID, sorting: sorting, moc: self.moc)
    }
    
    public func subscribeToNode(_ node: NodeIdentifier) -> Node? {
        self.storage.fetchNode(id: node, moc: self.moc)
    }

    public func subscribeToTrash(volumeID: String) -> NSFetchedResultsController<Node> {
        storage.subscriptionToTrash(volumeID: volumeID, moc: moc)
    }
    
    public func subscribeToOfflineAvailable() -> NSFetchedResultsController<Node> {
        storage.subscriptionToOfflineAvailable(withInherited: false, moc: moc)
    }
    
    public func subscribeToStarred(share shareID: String, sorting: SortPreference) -> NSFetchedResultsController<Node> {
        storage.subscriptionToStarred(share: shareID, sorting: sorting, moc: moc)
    }
    
    public func subscribeToShared(volumeID: String, sorting: SortPreference) -> NSFetchedResultsController<Node> {
        storage.subscriptionToShared(volumeID: volumeID, sorting: sorting, moc: moc)
    }

    public func subscribeToPublicLinkShared(sorting: SortPreference) -> NSFetchedResultsController<Node> {
        storage.subscriptionToPublicLinkShared(sorting: sorting, moc: moc)
    }

    public func subscribeToSharedWithMe(sorting: SortPreference) -> NSFetchedResultsController<Node> {
        storage.subscriptionToSharedWithMe(sorting: sorting, moc: moc)
    }
}
