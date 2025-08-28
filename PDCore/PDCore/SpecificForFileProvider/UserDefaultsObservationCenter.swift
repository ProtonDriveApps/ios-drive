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

public final class UserDefaultsObservationCenter {
    private class Observation {
        weak var observer: AnyObject?
        let keyValueObservation: NSKeyValueObservation

        init(observer: AnyObject, keyValueObservation: NSKeyValueObservation) {
            self.observer = observer
            self.keyValueObservation = keyValueObservation
        }
    }

    private let store: UserDefaults
    private var observations = [Observation]()
    
    private let additionalLogging: Bool
    private let instanceIdentifier = UUID()

    public init(userDefaults: UserDefaults, additionalLogging: Bool = false) {
        self.store = userDefaults
        self.additionalLogging = additionalLogging
        if additionalLogging {
            Log.debug("UserDefaultsObservationCenter init: \(instanceIdentifier.uuidString)", domain: .syncing)
        }
    }

    deinit {
        observations.forEach { observation in
            if additionalLogging {
                Log.debug("UserDefaultsObservationCenter \(instanceIdentifier.uuidString): removing observation \(observation)", domain: .syncing)
            }
            observation.keyValueObservation.invalidate()
        }
        if additionalLogging {
            Log.debug("UserDefaultsObservationCenter deinit: \(instanceIdentifier.uuidString)", domain: .syncing)
        }
    }

    public func addObserver<Value>(_ observer: AnyObject, of key: KeyPath<UserDefaults, Value>, using handler: @escaping (Value?) -> Void) {
        let additionalLogging = self.additionalLogging
        let instanceIdentifier = self.instanceIdentifier
        let keyValueObservation = store.observe(key, options: [.new]) { _, change in
            if additionalLogging {
                Log.debug("UserDefaultsObservationCenter \(instanceIdentifier.uuidString) \(key): change handler, value \(String(describing: change.newValue))", domain: .syncing)
            }
            handler(change.newValue)
        }
        let observation = Observation(observer: observer, keyValueObservation: keyValueObservation)
        self.observations.append(observation)
        if additionalLogging {
            Log.debug("UserDefaultsObservationCenter \(instanceIdentifier.uuidString) \(key): adding observation \(observation)", domain: .syncing)
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        self.observations = observations.filter { observation in
            // Clear up any deallocated observers as well as this observer
            if observation.observer == nil || observer === observation.observer {
                observation.keyValueObservation.invalidate()
                if additionalLogging {
                    Log.debug("UserDefaultsObservationCenter \(instanceIdentifier.uuidString): removing observation \(observation)", domain: .syncing)
                }
                return false
            }

            return true
        }
    }
}
