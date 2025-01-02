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
import SwiftUI
import PMSettings
import ProtonCoreKeymaker
import LocalAuthentication

extension Keymaker: AutoLocker {
    public var autolockerTimeout: LockTime {
        .init(rawValue: DriveKeychain.shared.lockTime.rawValue)
    }

    public func setAutolockerTimeout(_ timeout: LockTime) {
        DriveKeychain.shared.lockTime = .init(rawValue: timeout.rawValue)
    }
}

extension Keymaker: Unlocker {
    public var isBioProtected: Bool {
        isProtectorActive(BioProtection.self)
    }

    public var isPinProtected: Bool {
        isProtectorActive(PinProtection.self)
    }

    public func bioUnlock(completion: @escaping UnlockResult) {
        obtainMainKey(with: BioProtection(keychain: DriveKeychain.shared), handler: { key in
            guard let key = key, !key.isEmpty else {
                return completion(false)
            }
            completion(true)
        })
    }

    public func pinUnlock(pin: String, completion: @escaping UnlockResult) {
        obtainMainKey(with: PinProtection(pin: pin, keychain: DriveKeychain.shared), handler: { key in
            guard let key = key, !key.isEmpty else {
                return completion(false)
            }
            completion(true)
        })
    }
}
