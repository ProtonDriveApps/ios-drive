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
import ProtonCoreKeymaker

public final class DriveKeychain: Keychain {
    public init() {
        super.init(service: "ch.protonmail", accessGroup: Self.keychainGroup)
    }
    
    public static let keychainGroup = Constants.developerGroup + Constants.appGroup
    
    // we use the single instance of DriveKeychain because
    // the access to the keychain is serialized by the dispatch queue on the instance level for the thread-safety,
    // so if we want to take advantage of that thread-safety serialization, we need to use the single instance
    public private(set) static var shared = DriveKeychain()
    
    // only for testing
    @discardableResult
    static internal func recreateSharedInstance() -> (DriveKeychain, DriveKeychain) {
        let old = shared
        let new = DriveKeychain()
        shared = new
        return (old, new)
    }
}

extension DriveKeychain: SettingsProvider {
    private static let LockTimeKey = "DriveKeychain.LockTimeKey"
    
    public var lockTime: AutolockTimeout {
        get {
            guard let string = self.string(forKey: DriveKeychain.LockTimeKey), let intValue = Int(string) else {
                return .never
            }
            return AutolockTimeout(rawValue: intValue)
        }
        set {
            self.set(String(newValue.rawValue), forKey: DriveKeychain.LockTimeKey)
        }
    }
}
