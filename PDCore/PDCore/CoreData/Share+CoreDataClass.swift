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

@objc(Share)
public class Share: NSManagedObject {
    public typealias Flags = PDClient.Share.Flags
    
    // private raw values
    @NSManaged fileprivate var linkTypeRaw: NSNumber?
    @NSManaged fileprivate var flagsRaw: Int
    @NSManaged fileprivate var permissionMaskRaw: Int
    #if os(iOS)
    var _observation: Any?
    #endif
    
    // public enums, wrapped
    @ManagedEnum(raw: #keyPath(flagsRaw)) public var flags: Flags?
    
    // dangerous injection, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._flags.configure(with: self)
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(_observation as Any)
        #endif
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        #if os(iOS)
        if type != .photos {
            self._observation = self.subscribeToContexts()
        }
        #endif
    }
    
    override public func willChangeValue(forKey key: String) {
        switch key {
        case #keyPath(passphrase): self.clearPassphrase = nil
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

    public var isMain: Bool {
        flags.contains(.main)
    }

    public var isCollaborativelyShared: Bool {
        type == .standard
    }
}

#if os(iOS)
extension Share: HasTransientValues {}
#endif

extension Optional where Wrapped == PDClient.Share.Flags {
    public func contains(_ member: Wrapped) -> Bool {
        self?.contains(member) ?? false
    }
}
