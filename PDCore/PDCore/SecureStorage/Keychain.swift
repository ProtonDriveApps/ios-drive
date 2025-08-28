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

public final class KeychainProvider {
    public static let shared = KeychainProvider()
    public var keychain: DriveKeychainProtocol = DriveKeychain.shared

    private init() { }
}

public protocol DriveKeychainProtocol {

    @available(*, deprecated, message: "Please use the throwing alternative: dataOrError(forKey:) and handle the error")
    func data(forKey key: String, attributes: [CFString: Any]?) -> Data?
    
    @available(*, deprecated, message: "Please use the throwing alternative: setOrError(:forKey:) and handle the error")
    func set(_ data: Data, forKey key: String, attributes: [CFString: Any]?)
    
    @available(*, deprecated, message: "Please use the throwing alternative: setOrError(:forKey:) and handle the error")
    func set(_ string: String, forKey key: String, attributes: [CFString: Any]?)
    
    func setOrError(_ data: Data, forKey key: String, attributes: [CFString: Any]?) throws
    
    func setOrError(_ string: String, forKey key: String, attributes: [CFString: Any]?) throws
    
    func dataOrError(forKey key: String, attributes: [CFString: Any]?) throws -> Data?
    
    func removeOrError(forKey key: String) throws
    
    @available(*, deprecated, message: "Please use the throwing alternative: removeOrError(forKey:) and handle the error")
    func remove(forKey key: String)
}

public final class DriveKeychain: Keychain, DriveKeychainProtocol {
    public init() {
        super.init(service: "ch.protonmail", accessGroup: Constants.keychainGroup)
    }
    
    // we use the single instance of DriveKeychain because
    // the access to the keychain is serialized by the dispatch queue on the instance level for the thread-safety,
    // so if we want to take advantage of that thread-safety serialization, we need to use the single instance
    public private(set) static var shared = DriveKeychain()
    
    // only for testing
    @discardableResult
    internal static func recreateSharedInstance() -> (DriveKeychain, DriveKeychain) {
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
            guard let string = try? stringOrError(forKey: DriveKeychain.LockTimeKey), let intValue = Int(string) else {
                return .never
            }
            return AutolockTimeout(rawValue: intValue)
        }
        set {
            try? setOrError(String(newValue.rawValue), forKey: DriveKeychain.LockTimeKey)
        }
    }
}

#if DEBUG
public final class TestKeychain: DriveKeychainProtocol {
    public private(set) static var shared = TestKeychain()

    private var dict: [String: Data] = [:]
    private let serialQueue = DispatchQueue(label: "test.keychain")
    var error: Error?

    public func data(forKey key: String, attributes: [CFString: Any]?) -> Data? {
        serialQueue.sync {
            dict[key]
        }
    }
    
    public func set(_ data: Data, forKey key: String, attributes: [CFString: Any]?) {
        try? setOrError(data, forKey: key, attributes: attributes)
    }
    
    public func set(_ string: String, forKey key: String, attributes: [CFString: Any]?) {
        try? setOrError(string, forKey: key, attributes: attributes)
    }

    public func setOrError(_ data: Data, forKey key: String, attributes: [CFString: Any]?) throws {
        try serialQueue.sync {
            if let error { throw error }
            dict[key] = data
        }
    }
    
    public func setOrError(_ string: String, forKey key: String, attributes: [CFString: Any]?) throws {
        try serialQueue.sync {
            if let error { throw error }
            dict[key] = Data(string.utf8)
        }
    }
    
    public func dataOrError(forKey key: String, attributes: [CFString: Any]?) throws -> Data? {
        try serialQueue.sync {
            if let error { throw error }
            return dict[key]
        }
    }
    
    public func removeOrError(forKey key: String) throws {
        try serialQueue.sync {
            if let error { throw error }
            dict[key] = nil
        }
    }
    
    public func remove(forKey key: String) {
        serialQueue.sync {
            dict[key] = nil
        }
    }
}
#endif
