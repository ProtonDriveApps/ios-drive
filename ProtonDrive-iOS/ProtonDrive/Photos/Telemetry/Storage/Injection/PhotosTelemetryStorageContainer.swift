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

final class PhotosTelemetryStorageContainer {
    struct Dependencies {
        let tower: Tower
        let settingsSuite: SettingsStorageSuite
    }

    private let storageController: PhotosTelemetryStorageController
    let storage: PhotosTelemetryStorage

    init(dependencies: Dependencies) {
        let factory = PhotosTelemetryStorageFactory()
        storage = factory.makeStorage(suite: dependencies.settingsSuite)
        storageController = factory.makeController(tower: dependencies.tower, storage: storage)
    }

    func makeUploadFinishResource() -> PhotoUploadFinishResource {
        PhotosTelemetryStorageFactory().makeUploadFinishResource(storage: storage)
    }

    func makeShareCreationFinishResource() -> PhotoShareCreationFinishResource {
        PhotosTelemetryStorageFactory().makeShareCreationFinishResource(storage: storage)
    }
}
