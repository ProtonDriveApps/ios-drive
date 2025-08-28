// Copyright (c) 2025 Proton AG
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
import SwiftUI

public struct LockingBannerFactory {
    public init() {}

    public func makeLegacyBanner(
        backupNotifier: WorkingNotifier,
        tagMigrationNotifier: WorkingNotifier,
        repository: ScreenLockingBannerRepository
    ) -> some View {
        let controller = makeController(
            backupNotifier: backupNotifier,
            tagMigrationNotifier: tagMigrationNotifier,
            repository: repository
        )
        return makeBanner(controller: controller)
    }

    public func makeBanner(controller: ScreenLockController) -> some View {
        let viewModel = LockingBannerViewModel(controller: controller)
        return LockingBannerView(viewModel: viewModel)
    }

    public func makeController(
        backupNotifier: WorkingNotifier,
        tagMigrationNotifier: WorkingNotifier,
        repository: ScreenLockingBannerRepository
    ) -> ScreenLockController {
        return PhotosUploadingScreenLockController(
            backupNotifier: backupNotifier,
            tagMigrationNotifier: tagMigrationNotifier,
            lockingResource: UIApplication.shared,
            visibilityRepository: repository
        )
    }
}
