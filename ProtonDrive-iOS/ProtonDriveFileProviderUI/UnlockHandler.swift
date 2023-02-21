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
import PDCore
import ProtonCore_Keymaker
import ProtonCore_Settings
import os.log

protocol UnlockHandlerDelegate: AnyObject {
    func sealMainKey()
}

final class UnlockHandler: LogObject, Unlocker {
    static let osLog: OSLog = OSLog(subsystem: "Keymaker", category: "LockScreen")

    weak var delegate: UnlockHandlerDelegate?
    let keymaker: Keymaker

    internal init(keymaker: Keymaker, delegate: FileProviderUIViewController) {
        self.keymaker = keymaker
        self.delegate = delegate
    }

    var isBioProtected: Bool {
        keymaker.isBioProtected
    }

    var isPinProtected: Bool {
        keymaker.isPinProtected
    }

    func bioUnlock(completion: @escaping UnlockResult) {
        keymaker.bioUnlock { [weak self] isSuccess in
            #if DEBUG
            let message = isSuccess ? "Unlock with BIO ✅." : "Tried to unlock with BIO ❌."
            ConsoleLogger.shared?.log(message, osLogType: Self.self)
            #endif
            self?.delegate?.sealMainKey()
            completion(isSuccess)
        }
    }

    func pinUnlock(pin: String, completion: @escaping UnlockResult) {
        keymaker.pinUnlock(pin: pin) { [weak self] isSuccess in
            #if DEBUG
            let message = isSuccess ? "Unlock with PIN ✅." : "Tried to unlock with BIO ❌."
            ConsoleLogger.shared?.log(message, osLogType: Self.self)
            #endif
            self?.delegate?.sealMainKey()
            completion(isSuccess)
        }
    }

}
