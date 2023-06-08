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
import UIKit
import ProtonCore_Foundations

final class PhotosCoordinator: PhotosRootCoordinator, PhotosPermissionsCoordinator, PhotoItemCoordinator {
    weak var rootViewController: UIViewController?
    weak var container: PhotosContainer?

    private var navigationViewController: UINavigationController? {
        rootViewController?.navigationController
    }

    func openMenu() {
        NotificationCenter.default.post(.toggleSideMenu)
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.openURLIfPossible(url)
        }
    }

    func openPreview(with id: PhotoId) {
        guard let container = container else {
            return
        }
        let viewController = container.makePreviewViewController(with: id)
        viewController.modalPresentationStyle = .fullScreen
        navigationViewController?.present(viewController, animated: true)
    }
}
