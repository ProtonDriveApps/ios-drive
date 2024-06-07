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

import Foundation
import ProtonCoreKeymaker

/// Source of truth for protection setup and current lock state.
public protocol ProtectionResource {
    /// Is any protection strategy set up.
    func isProtected() -> Bool
    /// Is a protection strategy set up and currently active.
    func isLocked() -> Bool
}

extension Keymaker: ProtectionResource {
    public func isProtected() -> Bool {
        isProtectorActive(BioProtection.self) || isProtectorActive(PinProtection.self)
    }

    public func isLocked() -> Bool {
        isProtected() ? !isMainKeyInMemory : false
    }
}
