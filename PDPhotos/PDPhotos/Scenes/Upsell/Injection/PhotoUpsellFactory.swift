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
import PDCoreIOS
import SwiftUI

public struct PhotoUpsellFactory {
    public init() {}
    
    public func makeController(
        tower: Tower,
        coordinator: PhotoUpsellCoordinator,
        notificationsPermissionsFlowController: NotificationsPermissionsFlowController,
        photoUploadedNotifier: PhotoUploadedNotifier,
        photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol
    ) -> PhotoUpsellFlowController? {
        guard tower.localSettings.isPhotoUpsellShown == false else { return nil }

        return ConcretePhotoUpsellFlowController(
            coordinator: coordinator,
            photoUploadedNotifier: photoUploadedNotifier,
            localSettings: tower.localSettings,
            userInfoController: UserInfoControllerFactory().makeController(sessionVault: tower.sessionVault),
            notificationsPermissionsFlowController: notificationsPermissionsFlowController,
            photoUpsellResultNotifier: photoUpsellResultNotifier
        )
    }

    public func makeView(
        coordinator: PhotoUpsellCoordinator,
        photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol,
        rootViewController: UIViewController
    ) -> UIViewController {
        let viewModel = PhotoUpsellViewModel(
            photosCoordinator: coordinator,
            photoUpsellResultNotifier: photoUpsellResultNotifier
        ) { [weak rootViewController] in
            rootViewController?.dismiss(animated: false)
        }
        let view = PhotoUpsellView(viewModel: viewModel)
        return UIHostingController(rootView: view)
    }
}
