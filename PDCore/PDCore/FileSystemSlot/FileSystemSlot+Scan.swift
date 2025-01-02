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

extension Node {
    var filesystemName: String {
        do {
            return try self.decryptName()
        } catch _ {
            return String(self.id.prefix(20))
        }
    }
}
extension Share {
    var filesystemName: String {
        String(self.id.prefix(20))
    }
}

public class FileSystemSlot {
    internal init(baseURL: URL, storage: StorageManager, syncStorage: SyncStorageManager?) {
        self.baseURL = baseURL
        self.storage = storage
        self.syncStorage = syncStorage
    }
    
    public let baseURL: URL
    public let storage: StorageManager
    public let syncStorage: SyncStorageManager?
    public var moc: NSManagedObjectContext {
        self.storage.backgroundContext
    }
    
    enum Errors: Error {
        case unknownTypeOfNode
        case fileDoesNotHaveActiveRevision
    }
    
    func clear() {
        try? FileManager.default.removeItem(at: self.baseURL)
    }
    
    // MARK: - SUBSCRIBE TO DB CHANGES
    
    public func getNode(_ identifier: NodeIdentifier, moc: NSManagedObjectContext? = nil) -> Node? {
        self.storage.fetchNode(id: identifier, moc: moc ?? self.moc)
    }
    
    public func getDraft(_ localID: String, shareID: String) -> File? {
        self.storage.fetchDraft(localID: localID, shareID: shareID, moc: self.moc)
    }
    
    public func getMainShare(of creatorAddresses: Set<String>) -> Share? {
        self.storage.mainShareOfVolume(by: creatorAddresses, moc: self.moc)
    }
    
    public func getChildren(of parentID: NodeIdentifier, sorting: SortPreference) -> [Node] {
        let result = try? self.storage.fetchChildren(of: parentID.nodeID, share: parentID.shareID, sorting: sorting, moc: self.moc)
        return result ?? []
    }
    
    public func getNodes(of shareID: String) -> [Node] {
        let result = self.storage.fetchNodes(of: shareID, moc: self.moc)
        return result
    }
    
    // MARK: - SEND FROM DB TO FS
    
    public func subscribeToChildren(of parentID: NodeIdentifier) -> NSFetchedResultsController<Node> {
        self.storage.subscriptionToChildren(ofNode: parentID, sorting: .default, moc: self.moc)
    }
}

extension FileSystemSlot {
    internal func composeUrl(of tail: Node) -> URL {
        var intermediateNodes: [String] = []
        
        var node: Node? = tail
        while node != nil {
            if let next = node!.parentLink {
                intermediateNodes.append(next.filesystemName)
            } else {
                intermediateNodes.append(node!.primaryDirectShare!.filesystemName) // root folder
            }
            node = node?.parentLink
        }
        
        let parentUrl: URL = intermediateNodes.reversed().reduce(self.baseURL) { url, name in
            url.appendingPathComponent(name, isDirectory: true)
        }
        
        return parentUrl
    }
}
