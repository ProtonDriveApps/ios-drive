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

@objc(Node)
public class Node: NSManagedObject, HasTransientValues {
    public enum State: Int, Codable {
        case active = 1, deleted, deleting
        case uploading, waiting, pausedUpload
    }
    
    var _observation: Any?
    @NSManaged private(set) var stateRaw: NSNumber? // used in fetch request predicated inside PDCore, should not be shown outside
    
    @ManagedEnum(raw: #keyPath(stateRaw)) public var state: State?
    
    // dangerous, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._state.configure(with: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(_observation as Any)
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        self._observation = self.subscribeToContexts()
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
        NotificationCenter.default.removeObserver(_observation as Any)
    }
}

extension Node.State {
    init?(_ nodeState: PDClient.NodeState) {
        switch nodeState {
        case .active: self = .active
        case .deleted: self = .deleted
        case .deleting: self = .deleting
        case .errorState: self = .deleting
        }
    }
    
    public var existsOnCloud: Bool {
        switch self {
        case .active, .deleted, .deleting: return true
        case .uploading, .waiting, .pausedUpload: return false
        }
    }
    
    public var isUploading: Bool {
        switch self {
        case .active, .deleted, .deleting: return false
        case .uploading, .waiting, .pausedUpload: return true
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
