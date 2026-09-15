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
import PDClient

@propertyWrapper
public final class PersistedFeatureFlag {
    public let flag: ExternalFeatureFlag
    private let valueStorage: SettingsStorage<Bool>
    private var payloadStorage: SettingsStorage<String>?

    /// - Parameter key: UserDefaults key for the stored value. Defaults to `flag.rawValue`.
    ///   Pass an explicit key only for legacy flags whose stored key differs from the Unleash name.
    public init(_ flag: ExternalFeatureFlag, key: String? = nil) {
        self.flag = flag
        self.valueStorage = SettingsStorage(key ?? flag.rawValue)
        if flag.hasPayload {
            self.payloadStorage = SettingsStorage(flag.rawValue + "Payload")
        }
    }

    public func configure(with suite: SettingsStorageSuite) {
        valueStorage.configure(with: suite)
        payloadStorage?.configure(with: suite)
    }

    public var wrappedValue: Bool {
        get { valueStorage.wrappedValue ?? false }
        set { valueStorage.wrappedValue = newValue }
    }

    public var payload: String? {
        get { payloadStorage?.wrappedValue }
        set { payloadStorage?.wrappedValue = newValue }
    }

    public var projectedValue: PersistedFeatureFlag { self }

    func clearValue(clearPayload: Bool = true) {
        valueStorage.wrappedValue = nil
        if clearPayload {
            payloadStorage?.wrappedValue = nil
        }
    }
}
