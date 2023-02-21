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

@propertyWrapper
public struct FastStorage<T> {
    let key: String

    public init(_ key: String) {
        self.key = key
    }

    public var wrappedValue: T? {
        get {
            return UserDefaults.standard.object(forKey: key) as? T
        }
        set {
            guard let newValue = newValue else {
                return UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct FastCollectionStorage<T> where T: Codable {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var wrappedValue: [T] {
        get {
            guard let data = UserDefaults.standard.object(forKey: key) as? Data else { return [] }
            return (try? PropertyListDecoder().decode([T].self, from: data)) ?? []
        }
        set {
            guard !newValue.isEmpty,
                let data = try? PropertyListEncoder().encode(newValue) else
            {
                return UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
