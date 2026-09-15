// Copyright (c) 2026 Proton AG
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

import Combine
import PDLocalization
import PDUIComponents
import SwiftUI

@MainActor
final class VolumeLockBannerViewModel: ObservableObject {
    var shouldShowBanner: Bool {
        controller.shouldShowBanner
    }

    let bannerViewModel: LockedStateTopBannerViewModel

    private let controller: VolumeLockController
    private let coordinator: VolumeLockCoordinator
    private var cancellable: AnyCancellable?

    init(controller: VolumeLockController, coordinator: VolumeLockCoordinator) {
        self.controller = controller
        self.coordinator = coordinator
        self.bannerViewModel = LockedStateTopBannerViewModel(
            data: LockedStateTopBannerViewData(
                severance: .error,
                title: Localization.volume_lock_banner_restore,
                description: nil,
                actionButton: Localization.volume_lock_banner_details,
                secondaryActionButton: Localization.volume_lock_banner_skip,
                buttonUrl: nil
            ),
            showsDismissButton: true,
            onPrimaryAction: { [weak coordinator] in
                Task { @MainActor in
                    coordinator?.presentRecoveryDetails(from: nil)
                }
            },
            onSecondaryAction: { [weak coordinator, weak controller] in
                Task { @MainActor in
                    coordinator?.presentSkipConfirmation(from: nil) {
                        controller?.skipBannerPermanently()
                    }
                }
            },
            onDismissAction: { [weak controller] in
                Task { @MainActor in
                    controller?.dismissBanner()
                }
            }
        )
        cancellable = controller.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
