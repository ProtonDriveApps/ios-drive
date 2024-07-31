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

@objc(Volume)
public class Volume: NSManagedObject {
    public typealias RestoreStatus = PDClient.Volume.RestoreStatus
    public typealias State = PDClient.Volume.State
    
    // private raw values
    @NSManaged fileprivate var restoreStatusRaw: Int
    @NSManaged fileprivate var stateRaw: Int

    @ManagedEnum(raw: #keyPath(restoreStatusRaw)) public var restoreStatus: RestoreStatus?
    @ManagedEnum(raw: #keyPath(stateRaw)) public var state: State?
    
    // dangerous, see https://developer.apple.com/documentation/coredata/nsmanagedobject
    override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        self._restoreStatus.configure(with: self)
        self._state.configure(with: self)
    }
}
