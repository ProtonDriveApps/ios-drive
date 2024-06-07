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

@objc(ShareURL)
public class ShareURL: NSManagedObject {
    public typealias Permissions = ShareURLMeta.Permissions
    public typealias Flags = ShareURLMeta.Flags

    #if os(iOS)
    var _observation: Any?
    #endif
    
    // public enums, wrapped
    @ManagedEnum(raw: #keyPath(permissionsRaw)) public var permissions: Permissions!
    @ManagedEnum(raw: #keyPath(flagsRaw)) public var flags: Flags!
    
    // dangerous injection, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._permissions.configure(with: self)
        self._flags.configure(with: self)
    }

    public var hasCustomPassword: Bool {
        Flags.customPasswordFlags.contains(flags)
    }

    public var hasNewFormat: Bool {
        Flags.newFormatPasswordFlags.contains(flags)
    }

    override public func awakeFromFetch() {
        super.awakeFromFetch()
        #if os(iOS)
        self._observation = self.subscribeToContexts()
        #endif
    }

    override public func willTurnIntoFault() {
        super.willTurnIntoFault()
        #if os(iOS)
        NotificationCenter.default.removeObserver(_observation as Any)
        #endif
    }

    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(_observation as Any)
        #endif
    }
}

#if os(iOS)
extension ShareURL: HasTransientValues {}
#endif
