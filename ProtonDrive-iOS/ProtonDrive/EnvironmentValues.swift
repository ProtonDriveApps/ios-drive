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

import SwiftUI
import PDCore
import ProtonCoreKeymaker
import PDUIComponents

// MARK: - Keymaker
@available(*, deprecated, message: "Refactor this out: used only in this file")
extension EnvironmentValues {
    var keymaker: DriveKeymaker {
        get { self[KeymakerKey.self] }
        set { self[KeymakerKey.self] = newValue }
    }
}

@available(*, deprecated, message: "Refactor this out: used only in this file")
private struct KeymakerKey: EnvironmentKey {
    static var defaultValue = DriveKeymaker(autolocker: Environment(\.autolocker).wrappedValue, keychain: DriveKeychain.shared)
}

// MARK: - AutoLocker
@available(*, deprecated, message: "Refactor this out: used only in this file")
extension EnvironmentValues {
    var autolocker: Autolocker {
        get { self[KeymakerAutolockerKey.self] }
        set { self[KeymakerAutolockerKey.self] = newValue }
    }
}
@available(*, deprecated, message: "Refactor this out: used only in this file")
private struct KeymakerAutolockerKey: EnvironmentKey {
    static var defaultValue = Autolocker(lockTimeProvider: DriveKeychain.shared)
}

// MARK: - StorageKey
@available(*, deprecated, message: "Refactor this out: used only in this file")
extension EnvironmentValues {
    var storage: StorageManager {
        get { self[StorageKey.self] }
        set { self[StorageKey.self] = newValue }
    }
}

@available(*, deprecated, message: "Refactor this out: used only in AppDelegate.applicationWillTerminate")
private struct StorageKey: EnvironmentKey {
    static var defaultValue = StorageManager(suite: Constants.appGroup, sessionVault: Environment(\.initialServices.sessionVault).wrappedValue)
}

// MARK: - AcknowledgedNotEnoughStorageKey
extension EnvironmentValues {
    var acknowledgedNotEnoughStorage: Binding<Bool> {
        get { self[AcknowledgedNotEnoughStorageKey.self] }
        set { self[AcknowledgedNotEnoughStorageKey.self] = newValue }
    }
}
private struct AcknowledgedNotEnoughStorageKey: EnvironmentKey {
    // standard suite - will be in app's directory
    @SettingsStorage("acknowledgedNotEnoughStorage") private static var acknowledgedNotEnoughStorage: Bool?

    static var defaultValue = Binding<Bool>(
        get: { acknowledgedNotEnoughStorage ?? false },
        set: { acknowledgedNotEnoughStorage = $0 }
    )
}

// MARK: - InitialServicesKey
@available(*, deprecated, message: "Refactor this out: used only in this file")
extension EnvironmentValues {
    var initialServices: InitialServices {
        get { self[InitialServicesKey.self] }
        set { self[InitialServicesKey.self] = newValue }
    }
}

@available(*, deprecated, message: "Refactor this out: used only in this file")
private struct InitialServicesKey: EnvironmentKey {
    static var defaultValue = InitialServices(userDefault: Constants.appGroup.userDefaults,
                                              clientConfig: Constants.clientApiConfig,
                                              keymaker: Environment(\.keymaker).wrappedValue,
                                              sessionRelatedCommunicatorFactory: SessionRelatedCommunicatorForMainApp.init)
}
