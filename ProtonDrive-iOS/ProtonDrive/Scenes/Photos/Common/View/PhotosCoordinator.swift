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
import ProtonCoreFoundations
import UIKit

final class PhotosCoordinator: PhotosRootCoordinator, PhotosPermissionsCoordinator, PhotoItemCoordinator, PhotosActionCoordinator, PhotosStorageCoordinator, PhotosStateCoordinator {
    private let container: PhotosScenesContainer
    weak var rootViewController: UIViewController?

    private var navigationViewController: UINavigationController? {
        rootViewController?.navigationController
    }

    init(container: PhotosScenesContainer) {
        self.container = container
    }

    func openMenu() {
        NotificationCenter.default.post(.toggleSideMenu)
    }

    func close() {
        rootViewController?.dismiss(animated: true)
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.openURLIfPossible(url)
        }
    }

    func openPreview(with id: PhotoId) {
        let viewController = container.makePreviewController(id: id)
        viewController.modalPresentationStyle = .fullScreen
        navigationViewController?.present(viewController, animated: true)
    }

    func updateTabBar(isHidden: Bool) {
        let userInfo: [String: Bool] = ["tabBarHidden": isHidden]
        NotificationCenter.default.post(name: FinderNotifications.tabBar.name, object: nil, userInfo: userInfo)
    }

    func openShare(id: PhotoId) {
        guard let viewController = container.makeShareViewController(id: id) else {
            return
        }
        navigationViewController?.present(viewController, animated: true)
    }

    func openNativeShare(url: URL, completion: @escaping () -> Void) {
        guard let rootViewController = rootViewController else {
            return
        }

        let viewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        viewController.popoverPresentationController?.sourceView = rootViewController.view
        viewController.completionWithItemsHandler = { _, _, _, _ in
            completion()
        }
        rootViewController.present(viewController, animated: true, completion: nil)
    }

    func openSubscriptions() {
        let viewController = container.makeSubscriptionsViewController()
        let navigationViewController = ModalNavigationViewController(rootViewController: viewController)
        navigationViewController.modalPresentationStyle = .fullScreen
        rootViewController?.present(navigationViewController, animated: true)
    }
    
    func openRetryScreen() {
        let viewController = container.makeRetryViewController()
        rootViewController?.present(viewController, animated: true)
    }
}
