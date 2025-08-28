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

import SwiftUI

struct GalleryBannersView<
    ViewModel: GalleryBannersViewModelProtocol,
    StateView: View,
    LockingBannerView: View,
    StorageView: View,
    MigrationView: View
>: View {
    private let viewModel: ViewModel
    private let stateView: StateView
    private let lockingBannerView: LockingBannerView
    private let storageView: StorageView
    private let migrationView: MigrationView

    init(viewModel: ViewModel, stateView: StateView, lockingBannerView: LockingBannerView, storageView: StorageView, migrationView: MigrationView) {
        self.viewModel = viewModel
        self.stateView = stateView
        self.lockingBannerView = lockingBannerView
        self.storageView = storageView
        self.migrationView = migrationView
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.shouldShowMigration {
                migrationView
            } else {
                storageView
                lockingBannerView
                stateView
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
