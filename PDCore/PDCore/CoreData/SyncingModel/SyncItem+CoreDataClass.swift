// Copyright (c) 2024 Proton AG
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

import CoreData

@objc(SyncItem)
public class SyncItem: NSManagedObject {

    public typealias State = SyncItemState

    @NSManaged public var fileProviderOperationRaw: Int64
    @NSManaged public var stateRaw: Int64

    @ManagedEnum(raw: #keyPath(fileProviderOperationRaw)) public var fileProviderOperation: FileProviderOperation!

    @ManagedEnum(raw: #keyPath(stateRaw)) public var state: State!

    // dangerous, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._fileProviderOperation.configure(with: self)
        self._state.configure(with: self)
    }
}
