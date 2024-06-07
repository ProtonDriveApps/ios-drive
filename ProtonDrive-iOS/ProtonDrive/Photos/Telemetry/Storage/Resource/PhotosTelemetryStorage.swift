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

import PDCore

protocol PhotosTelemetryStorage: AnyObject {
    var uploadedFilesCount: Double { get set }
    var uploadedBytesCount: Double { get set }
    var backupDuration: Double { get set }
    var isInitialBackup: Bool { get set }
    func reset()
}

final class PhotosTelemetrySettingsStorage: PhotosTelemetryStorage {
    @SettingsStorage("uploadedFilesCountStorage") private var uploadedFilesCountStorage: Double?
    @SettingsStorage("uploadedBytesCountStorage") private var uploadedBytesCountStorage: Double?
    @SettingsStorage("backupDurationStorage") private var backupDurationStorage: Double?
    @SettingsStorage("isInitialBackupStorage") private var isInitialBackupStorage: Bool?

    var uploadedFilesCount: Double {
        get {
            uploadedFilesCountStorage ?? 0
        }
        set {
            uploadedFilesCountStorage = newValue
        }
    }

    var uploadedBytesCount: Double {
        get {
            uploadedBytesCountStorage ?? 0
        }
        set {
            uploadedBytesCountStorage = newValue
        }
    }

    var backupDuration: Double {
        get {
            backupDurationStorage ?? 0
        }
        set {
            backupDurationStorage = newValue
        }
    }

    var isInitialBackup: Bool {
        get {
            isInitialBackupStorage ?? false
        }
        set {
            isInitialBackupStorage = newValue
        }
    }

    init(suite: SettingsStorageSuite) {
        _uploadedFilesCountStorage.configure(with: suite)
        _uploadedBytesCountStorage.configure(with: suite)
    }

    func reset() {
        uploadedFilesCountStorage = nil
        uploadedBytesCountStorage = nil
        backupDurationStorage = nil
        isInitialBackupStorage = nil
    }
}
