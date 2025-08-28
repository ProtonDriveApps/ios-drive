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
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

protocol AlbumGalleryCoordinatorProtocol {
    func openAlbum(
        configuration: PhotosRootConfiguration,
        id: AnyVolumeIdentifier
    )
    func openAlbumCreationView(shouldOpenInvitation: Bool)
    func openInvitations()
}

final class AlbumGalleryCoordinator: AlbumGalleryCoordinatorProtocol, NavigationBarAppearanceConfigurable {
    let container: GallerySceneContainer
    let pendingInvitationsContainer: PendingInvitationsContainer
    weak var rootViewController: UIViewController?
    var navigationController: UINavigationController? { rootViewController?.navigationController }
    var defaultBarAppearance: NavigationBarAppearance?
    private lazy var customBarAppearance: NavigationBarAppearance = {
        UINavigationBarAppearance.transparent()
    }()

    init(
        container: GallerySceneContainer,
        pendingInvitationsContainer: PendingInvitationsContainer,
        rootViewController: UIViewController?
    ) {
        self.container = container
        self.rootViewController = rootViewController
        self.pendingInvitationsContainer = pendingInvitationsContainer
        storeDefaultAppearance()
    }

    func openAlbum(
        configuration: PhotosRootConfiguration,
        id: AnyVolumeIdentifier
    ) {
        guard let manager = container.parent?.parent?.dependencies.contactsManager else { return }
        let factory = AlbumDetailFactory()
        let vc = factory.makeAlbumDetail(
            parameters: .init(
                albumID: id,
                configuration: configuration,
                contactsController: ContactsController(contactsManager: manager),
                container: container,
                defaultAppearance: defaultBarAppearance,
                rootViewController: rootViewController
            )
        )
        prepareAppearanceAndPush(appearance: customBarAppearance, viewController: vc)
    }

    @MainActor
    func openAlbumCreationView(shouldOpenInvitation: Bool) {
        guard let rootContainer = container.parent?.parent else { return }
        guard let vc = AlbumCreationFactory().makeAlbumCreationView(
            container: rootContainer,
            rootViewController: rootViewController,
            shouldOpenInvitation: shouldOpenInvitation
        ) else { return }
        prepareAppearanceAndPush(appearance: customBarAppearance, viewController: vc)
    }

    func openInvitations() {
        setUpAppearance(defaultBarAppearance)
        let view = pendingInvitationsContainer.makePendingInvitationsListView()
        let viewController = view.embeddedInHostingController()
        prepareAppearanceAndPush(appearance: defaultBarAppearance, viewController: viewController)
    }

    private func prepareAppearanceAndPush(appearance: NavigationBarAppearance?, viewController: UIViewController) {
        setUpAppearance(appearance)
        navigationController?.pushViewController(viewController, animated: true)
    }
}
