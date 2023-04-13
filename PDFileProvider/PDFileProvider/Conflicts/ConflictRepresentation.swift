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

import PDCore
import FileProvider

public enum ConflictWinner {
    case remote
    case edit
    case delete
}

public protocol ConflictDetection {

    func identifyConflict(
        tower: Tower,
        basedOn item: NSFileProviderItem,
        changeType: ItemActionChangeType,
        request: NSFileProviderRequest?) -> (ConflictingOperation?, Node?)

}

public protocol ConflictResolution {

    /// Return the item and if there was a conflict that needed to be handled
    func resolveConflictOnItemIfNeeded(
        tower: Tower, item: NSFileProviderItem, changeType: ItemActionChangeType, request: NSFileProviderRequest?) -> (NSFileProviderItem, Bool)

}
