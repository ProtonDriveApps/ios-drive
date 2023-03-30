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
            guard let customDefaults = UserDefaults(suiteName: name) else {
                assert(false, "Shared UserDefaults could not be created.")
                return .standard
            }
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
    
    public init(_ label: String) {
        self.label = label
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
                return suite.userDefaults.removeObject(forKey: label)
            }
            suite.userDefaults.set(newValue, forKey: label)
        }
    }
}
