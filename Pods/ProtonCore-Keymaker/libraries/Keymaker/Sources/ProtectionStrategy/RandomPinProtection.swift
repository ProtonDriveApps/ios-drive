//
//  PinProtection.swift
//  ProtonCore-ProtonCore-Keymaker - Created on 01/08/2021.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

private enum RandomPinProtectionConstants {
    static let saltKeychainKey = "RandomPinProtection" + ".salt"
    static let versionKey = "RandomPinProtection" + ".version"
    static let numberOfIterations: Int = 32768
}

public struct RandomPinProtection: ProtectionStrategy {
    public static var keychainLabel: String {
        return "RandomPinProtection"
    }
    
    public let keychain: Keychain
    private let pin: String
    private var version: Version = .v1
    
    enum Version: String {
        case lagcy = "0"
        case v1 = "1"
        init(raw: String?) {
            let rawValue = raw ?? "0"
            switch rawValue {
            case "1":
                self = .v1
            default:
                self = .lagcy
            }
        }
    }
    
    public init(pin: String, keychain: Keychain) {
        self.pin = pin
        self.keychain = keychain
    }
    
    internal init(pin: String, keychain: Keychain, version: Version) {
        self.pin = pin
        self.keychain = keychain
        self.version = version
    }
    
    private typealias Const = RandomPinProtectionConstants
    
    enum Errors: Error {
        case saltNotFound
        case failedToDeriveKey
    }
    
    public func lock(value: MainKey) throws {
        let salt = RandomPinProtection.generateRandomValue(length: 8)
        var error: NSError?
        guard let ethemeralKey = CryptoSubtle.DeriveKey(pin, Data(salt), Const.numberOfIterations, &error) else {
            throw error ?? Errors.failedToDeriveKey
        }
        let locked = try Locked<MainKey>(clearValue: value, with: ethemeralKey.bytes)
        RandomPinProtection.saveCyphertext(locked.encryptedValue, in: self.keychain)
        self.keychain.set(Data(salt), forKey: Const.saltKeychainKey)
        self.keychain.set(self.version.rawValue, forKey: Const.versionKey)
    }
    
    public func unlock(cypherBits: Data) throws -> MainKey {
        guard let salt = self.keychain.data(forKey: Const.saltKeychainKey) else {
            throw Errors.saltNotFound
        }
        var error: NSError?
        guard let ethemeralKey = CryptoSubtle.DeriveKey(pin, salt, Const.numberOfIterations, &error) else {
            throw error ?? Errors.failedToDeriveKey
        }
        
        let curVer: Version = Version.init(raw: self.keychain.string(forKey: Const.versionKey))
        do {
            switch curVer {
            case .lagcy:
                let locked = Locked<MainKey>.init(encryptedValue: cypherBits)
                let key = try locked.lagcyUnlock(with: ethemeralKey.bytes)
                try self.lock(value: key)
                return key
            default:
                let locked = Locked<MainKey>.init(encryptedValue: cypherBits)
                return try locked.unlock(with: ethemeralKey.bytes)
            }
        } catch let error {
            throw error
        }
    }
    
    public static func removeCyphertext(from keychain: Keychain) {
        (self as ProtectionStrategy.Type).removeCyphertext(from: keychain)
        keychain.remove(forKey: Const.saltKeychainKey)
        keychain.remove(forKey: Const.versionKey)
    }
}
