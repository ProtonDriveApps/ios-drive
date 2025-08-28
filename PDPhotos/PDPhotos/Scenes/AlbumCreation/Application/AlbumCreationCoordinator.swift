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

import UIKit
import PDCore
import PDCoreIOS
import ProtonCoreUIFoundations
import PDUIComponents

final class AlbumCreationCoordinator: NavigationBarAppearanceConfigurable {
    private let container: PDPhotosContainer
    weak var rootViewController: UIViewController?
    var navigationController: UINavigationController? { rootViewController?.navigationController }
    var defaultBarAppearance: NavigationBarAppearance?
    private lazy var customBarAppearance: NavigationBarAppearance = {
        UINavigationBarAppearance.transparent()
    }()

    init(container: PDPhotosContainer, rootViewController: UIViewController? = nil) {
        self.container = container
        self.rootViewController = rootViewController
        storeDefaultAppearance()
    }

    func openPhotoPicker(selectionController: PhotosSelectionController) {
        setUpAppearance(defaultBarAppearance)
        let vc = container.makeRootViewController(
            configuration: .init(
                isPickingPhotos: true,
                selectionController: selectionController
            )
        )
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        navigationController?.present(nav, animated: true)
    }

    func dismissPicker() {
        navigationController?.presentedViewController?.dismiss(animated: true)
    }

    func showAlbumDetail(albumID: AnyVolumeIdentifier, shouldOpenInvitation: Bool) {
        guard
            let gallerySceneContainer = container.sceneContainer.gallerySceneContainer,
            let nav = navigationController
        else { return }
        setUpAppearance(customBarAppearance)
        let factory = AlbumDetailFactory()
        let controller = ContactsController(contactsManager: container.dependencies.contactsManager)
        let vc = factory.makeAlbumDetail(
            parameters: .init(
                albumID: albumID,
                configuration: .init(),
                contactsController: controller,
                container: gallerySceneContainer,
                defaultAppearance: defaultBarAppearance,
                rootViewController: rootViewController,
                shouldOpenInvitation: shouldOpenInvitation
            )
        )
        var viewControllers = nav.viewControllers
        viewControllers.removeLast()
        viewControllers.append(vc)
        nav.setViewControllers(viewControllers, animated: true)
    }
}
