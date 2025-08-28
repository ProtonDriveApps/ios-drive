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
import PDClient

public typealias CoreDataNode = Node

@objc(Node)
public class Node: NSManagedObject, VolumeUnique {
    public enum State: Int, Codable {
        case active = 1
        case deleted = 2
        case deleting = 3

        case uploading = 4          // Actively trying to upload
        case cloudImpediment = 5    // Waiting for more storage
        case paused = 6             // Paused by the user
        case interrupted = 7        // Paused by the system/app
    }
    var nameDecryptionFailed = false

    #if os(iOS)
    var _observation: Any?
    #endif
    @NSManaged private(set) var stateRaw: NSNumber? // used in fetch request predicated inside PDCore, should not be shown outside
    
    @ManagedEnum(raw: #keyPath(stateRaw)) public var state: State?

    public var parentNode: NodeWithNodeHashKey? {
        parentLink
    }

    // dangerous, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._state.configure(with: self)
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(_observation as Any)
        #endif
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        #if os(iOS)
        if !isRelatedToPhotos() {
            // Photos never change name or passphrase, so we don't need this overhead of refreshing them.
            self._observation = self.subscribeToContexts()
        }
        #endif
    }

    private func isRelatedToPhotos() -> Bool {
        return (self.self is Photo) || (self.self is Folder && primaryDirectShare?.type == .photos)
    }

    override public func willChangeValue(forKey key: String) {
        switch key {
        case #keyPath(name): self.clearName = nil
        case #keyPath(nodePassphrase): self.clearPassphrase = nil
        default: break
        }

        super.willChangeValue(forKey: key)
    }
    
    override public func willTurnIntoFault() {
        super.willTurnIntoFault()
        #if os(iOS)
        NotificationCenter.default.removeObserver(_observation as Any)
        #endif
    }

    // MARK: Root node

    final func findRootNode() -> Node {
        var currentNode: Node = self

        // Traverse up the parent chain until the root node (node with no parent) is found
        while let parentNode = currentNode.parentNode {
            currentNode = parentNode
        }

        return currentNode
    }
}

#if os(iOS)
extension Node: HasTransientValues {}
#endif

extension Node.State {
    init?(_ nodeState: PDClient.NodeState) {
        switch nodeState {
        case .draft: return nil
        case .active: self = .active
        case .deleted: self = .deleted
        case .deleting: self = .deleting
        }
    }
    
    public var existsOnCloud: Bool {
        switch self {
        case .active, .deleted, .deleting: return true
        case .uploading, .cloudImpediment, .paused, .interrupted: return false
        }
    }
    
    public var isUploading: Bool {
        switch self {
        case .active, .deleted, .deleting: return false
        case .uploading, .cloudImpediment, .paused, .interrupted: return true
        }
    }
}

extension Node {
    func setToBeDeletedRecursivelly() {
        guard !isToBeDeleted else { return }
        if isFolder {
            (self as! Folder).children.forEach { $0.setToBeDeletedRecursivelly() }
        }
        isToBeDeleted = true
    }
}
