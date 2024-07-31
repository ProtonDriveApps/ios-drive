// Copyright (c) 2024 Proton AG
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
import PDCore

protocol PhotosBackupBackgroundTelemetryStorageProtocol: AnyObject {
    /// Last BG session result
    var resultState: BackgroundTaskResultState? { get set }
    /// Flag to identify a background operation has been run at least once
    var hasStartedBackgroundOperation: Bool? { get set }
    /// Flag to identify if the operation is first or subsequent since app's launch
    var isFirstBackgroundOperation: Bool? { get set }
    /// Last activity start (app's launch / BG task launch)
    var lastActivityDate: Date? { get set }
}

final class PhotosBackupBackgroundTelemetryStorage: PhotosBackupBackgroundTelemetryStorageProtocol {
    @SettingsStorage("resultStateStorage") private var resultStateStorage: String?
    @SettingsStorage("hasStartedBackgroundOperationStorage") var hasStartedBackgroundOperation: Bool?
    @SettingsStorage("isFirstBackgroundOperationStorage") var isFirstBackgroundOperation: Bool?
    @SettingsStorage("lastActivityDateStorage") var lastActivityDate: Date?

    var resultState: BackgroundTaskResultState? {
        get {
            let state = SerializedBackgroundTaskResultState.init(rawValue: resultStateStorage ?? "")
            return state.map(\.backgroundTaskResultState)
        }
        set {
            let state = newValue.map(SerializedBackgroundTaskResultState.init(state:))
            resultStateStorage = state?.rawValue
        }
    }

    init(suite: SettingsStorageSuite) {
        _resultStateStorage.configure(with: suite)
        _hasStartedBackgroundOperation.configure(with: suite)
        _isFirstBackgroundOperation.configure(with: suite)
        _lastActivityDate.configure(with: suite)
    }
}

/// Serialization of `BackgroundTaskResultState`
private enum SerializedBackgroundTaskResultState: String {
    case expired
    case completed
    case foreground

    init(state: BackgroundTaskResultState) {
        switch state {
        case .expired:
            self = .expired
        case .completed:
            self = .completed
        case .foreground:
            self = .foreground
        }
    }

    var backgroundTaskResultState: BackgroundTaskResultState {
        switch self {
        case .completed:
            return .completed
        case .expired:
            return .expired
        case .foreground:
            return .foreground
        }
    }
}
