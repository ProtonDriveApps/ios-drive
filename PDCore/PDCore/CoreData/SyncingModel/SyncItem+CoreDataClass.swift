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

public typealias CoreDataSyncItem = SyncItem

@objc(SyncItem)
public class SyncItem: NSManagedObject {

    public typealias State = SyncItemState

    @NSManaged public var fileProviderOperationRaw: Int64
    @NSManaged public var stateRaw: Int64

    var state: SyncItemState {
        get {
            SyncItemState(rawValue: Int(stateRaw)) ?? .undefined
        }
        set {
            stateRaw = Int64(newValue.rawValue)
            inProgress = stateRaw == SyncItemState.inProgress.rawValue
            sortOrder = newValue.sortOrder
        }
    }

    var fileProviderOperation: FileProviderOperation {
        get {
            FileProviderOperation(rawValue: Int(fileProviderOperationRaw)) ?? .undefined
        }
        set {
            fileProviderOperationRaw = Int64(newValue.rawValue)
        }
    }
}

extension SyncItemState {
    /// Order in which states are shown in the tray app.
    /// Values lower than 0 are hidden.
    fileprivate var sortOrder: Int64 {
        switch self {
        case .inProgress: 100
        case .errored: 50
        case .cancelled: 0
        case .excludedFromSync: 0
        case .finished: 0
        case .undefined: -1
        }
    }
}
