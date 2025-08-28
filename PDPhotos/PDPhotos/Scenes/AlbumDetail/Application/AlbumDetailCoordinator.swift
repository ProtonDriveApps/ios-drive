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

import Foundation
import PDCore
import PDCoreIOS
import PDLocalization
import SwiftUI
import UIKit
import PDUIComponents

protocol AlbumDetailCoordinatorProtocol {
    func openMoreActionSheet(
        renameParameter: AlbumRenameViewModel.Parameters,
        renameHandler: @escaping (Error?) -> Void,
        deleteAlbumHandler: @escaping () -> Void
    )
    func openMoreActionSheetForGuest(
        leaveAlbumHandler: @escaping () -> Void
    )
    func pop()
    func openPhotoPicker(selectionController: PhotosSelectionController)
    func dismissPhotoPicker(completion: (() -> Void)?)
    func enableSwipeBack(isEnabled: Bool)
    func presentDeleteAlbumAlert(albumName: String, confirmHandler: @escaping () -> Void)
    func presentDeleteAlbumAndMovePhotosAlert(
        albumName: String,
        moveAndRemove: @escaping () -> Void,
        deleteWithoutSaving: @escaping () -> Void
    )
    func openSharingMemberConfiguration(
        identifier: AnyVolumeIdentifier,
        invitationResultController: InvitationResultControllerProtocol?
    )
    func presentLeaveAlbumAlert(
        albumName: String,
        leaveWithoutSaving: @escaping () -> Void,
        saveAndLeave: (() -> Void)?
    )
}

final class AlbumDetailCoordinator: AlbumDetailCoordinatorProtocol, NavigationBarAppearanceConfigurable {
    private let container: GallerySceneContainer
    weak var rootViewController: UIViewController?
    var defaultBarAppearance: NavigationBarAppearance?
    var navigationController: UINavigationController? { rootViewController?.navigationController }
    private let swipeBackRecognizerDelegate: SwipeBackRecognizerDelegate

    init(
        container: GallerySceneContainer,
        defaultBarAppearance: NavigationBarAppearance?,
        rootViewController: UIViewController? = nil
    ) {
        self.container = container
        self.defaultBarAppearance = defaultBarAppearance
        self.rootViewController = rootViewController
        self.swipeBackRecognizerDelegate = .init(navigationController: rootViewController?.navigationController)
        swipeBackRecognizerDelegate.enableSwipeGesture(isEnabled: true)
        updateTabBar(isHidden: true)
    }

    func openMoreActionSheet(
        renameParameter: AlbumRenameViewModel.Parameters,
        renameHandler: @escaping (Error?) -> Void,
        deleteAlbumHandler: @escaping () -> Void
    ) {
        guard let nav = navigationController else { return }
        ActionSheet.presentAlbumMoreActionSheet(
            on: nav,
            currentSort: .newestFirst
        ) { sort in
            
        } tapRename: { [weak self] in
            self?.openRenameView(parameter: renameParameter, renameHandler: renameHandler)
        } tapDeleteAlbum: {
            deleteAlbumHandler()
        }
    }

    func openMoreActionSheetForGuest(
        leaveAlbumHandler: @escaping () -> Void
    ) {
        guard let nav = navigationController else { return }
        ActionSheet.presentAlbumMoreActionSheetForGuest(
            on: nav,
            currentSort: .newestFirst
        ) { sort in

        } tapLeaveAlbum: {
            leaveAlbumHandler()
        }
    }

    private func openRenameView(
        parameter: AlbumRenameViewModel.Parameters,
        renameHandler: @escaping (Error?) -> Void
    ) {
        let provider = PhotoRootInfoProvider(
            dependencies: .init(
                managedObjectContext: container.dependencies.managedObjectContext,
                storageManager: container.dependencies.tower.storage
            )
        )
        let interactor = UpdateAlbumInteractor(
            dependencies: .init(
                client: container.dependencies.tower.client,
                managedObjectContext: container.dependencies.managedObjectContext,
                photoRootInfoProvider: provider,
                signersKitFactory: container.dependencies.tower.sessionVault,
                requestFactory: UpdateAlbumRequestFactory(
                    managedObjectContext: container.dependencies.managedObjectContext,
                    encryptionResource: Encryptor(),
                    signersKitFactory: container.dependencies.tower.sessionVault
                )
            )
        )
        let vm = AlbumRenameViewModel(
            dependencies: .init(interactor: interactor),
            parameters: parameter,
            renameHandler: renameHandler
        )
        let view = AlbumRenameView(viewModel: vm)
        let vc = UIHostingController(rootView: view)
        navigationController?.present(vc, animated: true)
    }

    func pop() {
        setUpAppearance(defaultBarAppearance)
        navigationController?.popViewController(animated: true)
        updateTabBar(isHidden: false)
    }

    func openPhotoPicker(selectionController: PhotosSelectionController) {
        guard let rootContainer = container.parent?.parent else { return }
        let vc = rootContainer.makeRootViewController(
            configuration: .init(
                isPickingPhotos: true,
                selectionController: selectionController
            )
        )
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        navigationController?.present(nav, animated: true)
    }

    func dismissPhotoPicker(completion: (() -> Void)?) {
        navigationController?.presentedViewController?.dismiss(animated: true, completion: completion)
    }

    func presentDeleteAlbumAlert(albumName: String, confirmHandler: @escaping () -> Void) {
        let title = Localization.delete_album_alert_title(name: albumName)
        let message = Localization.delete_album_alert_message(name: albumName)
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Localization.general_cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Localization.action_delete_album, style: .destructive, handler: { _ in
            confirmHandler()
        }))
        navigationController?.present(alert, animated: true)
    }

    func enableSwipeBack(isEnabled: Bool) {
        swipeBackRecognizerDelegate.enableSwipeGesture(isEnabled: isEnabled)
    }
    
    func presentDeleteAlbumAndMovePhotosAlert(
        albumName: String,
        moveAndRemove: @escaping () -> Void,
        deleteWithoutSaving: @escaping () -> Void
    ) {
        let title = Localization.delete_album_alert_title(name: albumName)
        let message = Localization.delete_album_and_move_alert_message
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Localization.general_cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Localization.action_delete_without_saving, style: .destructive, handler: { _ in
            deleteWithoutSaving()
        }))
        alert.addAction(.init(title: Localization.action_save_and_remove, style: .default, handler: { _ in
            moveAndRemove()
        }))
        navigationController?.present(alert, animated: true)
    }

    func presentLeaveAlbumAlert(
        albumName: String,
        leaveWithoutSaving: @escaping () -> Void,
        saveAndLeave: (() -> Void)?
    ) {
        let title = Localization.leave_album_alert_title(name: albumName)
        let message = Localization.leave_album_alert_message
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: Localization.general_cancel, style: .cancel))
        alert.addAction(.init(title: Localization.leave_album_without_saving_action, style: .destructive, handler: { _ in
            leaveWithoutSaving()
        }))
        if let saveAndLeave {
            alert.addAction(.init(title: Localization.leave_album_after_saving, style: .default, handler: { _ in
                saveAndLeave()
            }))
        }
        navigationController?.present(alert, animated: true)
    }

    func updateTabBar(isHidden: Bool) {
        NotificationCenter.default.post(name: DriveNotification.tabBar.name, object: isHidden)
    }
    
    func openSharingMemberConfiguration(
        identifier: AnyVolumeIdentifier,
        invitationResultController: InvitationResultControllerProtocol?
    ) {
        let context = container.dependencies.managedObjectContext
        Task {
            let album = await context.perform {
                CoreDataAlbum.fetch(identifier: identifier, in: context)
            }
            await MainActor.run {
                guard
                    let contactsManager = container.parent?.parent?.dependencies.contactsManager,
                    let album = album
                else { return }
                let dependencies = SharingMemberStartDependencies(
                    tower: container.dependencies.tower,
                    contactsManager: contactsManager,
                    featureFlagsController: container.dependencies.parentDependencies.featureFlagsController,
                    invitationResultController: invitationResultController,
                    rootViewController: rootViewController
                )
                let factory = SharingMemberStartFactory()
                let coordinator = factory.makeCoordinator(
                    dependencies: dependencies,
                    node: album
                )
                coordinator.openSharingConfig(sharingType: .album)
            }
        }
    }
}
