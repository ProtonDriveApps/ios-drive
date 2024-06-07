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
import PMSettings
import PDCore

public final class SecureFailedAttemptsCounter: FailedAttemptsCounter {
    private let keychainKey = "SecureFailedAttemptsCounter.count"
    private let keychain = DriveKeychain.shared
    
    public init(maximumNumberOfAttempts: Int) {
        self.maximumNumberOfAttempts = maximumNumberOfAttempts
    }
    
    public var maximumNumberOfAttempts: Int
    
    public var numberOfFailedAttempts: Int {
        get { self.getNumber() }
        set { self.setNumber(newValue) }
    }
    
    private func getNumber() -> Int {
        guard let string = keychain.string(forKey: keychainKey), let number = Int(string) else {
            return 0
        }
        return number
    }
    
    private func setNumber(_ number: Int) {
        keychain.set(String(number), forKey: keychainKey)
    }
}
