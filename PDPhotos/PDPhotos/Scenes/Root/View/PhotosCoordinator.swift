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

import Combine
import PDCore
import SwiftUI
import UIKit
import PDCoreIOS
import PDLocalization
import PDUIComponents

final class PhotosCoordinator: PhotosRootCoordinator {
    private let container: PDPhotosContainer
    weak var rootViewController: UIViewController?

    private var navigationViewController: UINavigationController? {
        rootViewController?.navigationController
    }

    init(container: PDPhotosContainer) {
        self.container = container
    }

    func openMenu() {
        // TODO: `Albums` related - needs refactoring of notifications
        let name = Notification.Name("DriveCoordinator.ToggleSideMenuNotification")
        NotificationCenter.default.post(name: name)
    }

    @MainActor
    func openAlbumCreationView() {
        guard let vc = AlbumCreationFactory().makeAlbumCreationView(
            container: container,
            rootViewController: rootViewController
        ) else { return }
        navigationViewController?.show(vc, sender: nil)
    }

    func close() {
        rootViewController?.dismiss(animated: true)
    }

    func openTagsMigrationSheet() {
        let factory = TagMigrationSheetFactory()
        let sheetViewController = factory.makeSheet()
        sheetViewController.modalPresentationStyle = .overFullScreen
        sheetViewController.view.backgroundColor = .clear

        // If the user enables photo backup on the settings page
        // and then navigates back to the photo tab
        // the popup appears immediately
        // However, since the navigation animation hasn't completed yet
        // this popup presentation is invalid
        // Add delay to make sure popup will be presented
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.rootViewController?.present(sheetViewController, animated: false)
        }
    }

    func openSubscription() {
        guard let galleryContainer = container.sceneContainer.gallerySceneContainer else { return }
        guard let rootViewController else {
            return
        }

        Task { @MainActor in
            let upsellCoordinator = galleryContainer.makeUpsellCoordinator()
            upsellCoordinator.present(from: rootViewController)
        }
    }

    func presentTagMigrationBanner() {
        let message = Localization.tags_migration_banner_text
        let model = BannerModel(message: message, style: .info)
        NotificationCenter.default.post(name: DriveNotification.banner.name, object: model)
    }
}
