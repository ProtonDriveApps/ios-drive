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

public enum SettingsStorageSuite {
    
    private static var groupUserDefaultInstances: [String: UserDefaults] = [:]
    
    case standard
    case group(named: String)
    case inMemory(initialContentFrom: URL)

    public var directoryUrl: URL {
        switch self {
        case let .group(named: appGroup):
            guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                assert(false, "Shared file container could not be created.")
                return FileManager.default.temporaryDirectory
            }
            return fileContainer
            
        case .standard:
            return FileManager.default.temporaryDirectory
        case let .inMemory(databaseUrl):
            return databaseUrl
        }
    }
    
    public var userDefaults: UserDefaults {
        switch self {
        case let .group(named: name):
            if let alreadyExistingUserDefaults = Self.groupUserDefaultInstances[name] {
                return alreadyExistingUserDefaults
            }
            guard let customDefaults = UserDefaults(suiteName: name) else {
                let message = "Shared UserDefaults for \(name) could not be created"
                Log.error(message, domain: .storage)
                assertionFailure(message)
                return .standard
            }
            Log.info("Shared UserDefaults for group \(name) created successfully.", domain: .storage)
            Self.groupUserDefaultInstances[name] = customDefaults
            return customDefaults
        case .standard, .inMemory:
            return .standard
        }
    }
}

@propertyWrapper
public class SettingsStorage<T> {
    private let label: String
    private var suite: SettingsStorageSuite = .standard
    
    private var additionalLogging: Bool
    
    public init(_ label: String, additionalLogging: Bool = false) {
        self.label = label
        self.additionalLogging = additionalLogging
    }
    
    public func configure(with suite: SettingsStorageSuite) {
        self.suite = suite
    }
    
    public var wrappedValue: T? {
        get {
            return suite.userDefaults.object(forKey: label) as? T
        }
        set {
            guard let newValue = newValue else {
                if additionalLogging {
                    Log.info("SettingsStorage: removing object for key: \(label)", domain: .syncing)
                }
                return suite.userDefaults.removeObject(forKey: label)
            }
            if additionalLogging {
                if let oldValue = suite.userDefaults.object(forKey: label) as? T {
                    Log.info("SettingsStorage: replacing \(oldValue) with \(newValue) for key: \(label)", domain: .syncing)
                } else {
                    Log.info("SettingsStorage: creating (first time) \(newValue) for key: \(label)", domain: .syncing)
                }
            }
            suite.userDefaults.set(newValue, forKey: label)
        }
    }
}

@propertyWrapper
public class SettingsCodableProperty<T: Codable> {
    private let key: String
    private let defaultValue: T
    private var suite: SettingsStorageSuite

    public init(wrappedValue: T, _ key: String, suite: SettingsStorageSuite = .group(named: Constants.appGroup)) {
        self.key = key
        self.defaultValue = wrappedValue
        self.suite = suite
    }

    public func configure(with suite: SettingsStorageSuite) {
        self.suite = suite
    }

    public var wrappedValue: T {
        get {
            guard let data = suite.userDefaults.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(newValue) {
                suite.userDefaults.set(data, forKey: key)
            }
        }
    }
}
