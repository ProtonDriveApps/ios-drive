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
import Foundation
import PDUIComponents
import PDCore
import PDCoreIOS
import PDContacts
import UIKit

protocol PhotosPreviewActionCoordinatorProtocol {
    func set(rootViewController: UIViewController)
    func openPhotoInfo(id: PhotoId)
    func openSharingConfiguration(for id: PhotoId, type: SharingConfigType)
    func openShareToSheet(selectionController: PhotosSelectionController, isDownloaded: Bool)
    func presentGroupToAlbumActionSheet(selectionController: PhotosSelectionController)
}

final class PhotosPreviewActionCoordinator: PhotosPreviewActionCoordinatorProtocol {
    private let gallerySceneContainer: GallerySceneContainer
    private let dependencies: Dependencies
    private var cancellables: Set<AnyCancellable> = []
    weak var rootViewController: UIViewController?
    private lazy var groupToAlbumController: GroupToAlbumSheetPresenterProtocol = {
        GroupToAlbumFactory().makePresenter(container: gallerySceneContainer, rootViewController: rootViewController)
    }()

    init(dependencies: Dependencies, gallerySceneContainer: GallerySceneContainer) {
        self.dependencies = dependencies
        self.gallerySceneContainer = gallerySceneContainer
    }

    func set(rootViewController: UIViewController) {
        self.rootViewController = rootViewController
    }

    func openPhotoInfo(id: PhotoId) {
        let storage = dependencies.storage

        let photo = storage.mainContext.performAndWait {
            let photo: PDCore.Photo? = PDCore.Photo.fetch(identifier: id, in: storage.mainContext)
            return photo
        }
        guard let photo else { return }

        let root = RootViewModel()

        let hosting = NodeDetailsCoordinator()
            .start((dependencies.tower, photo))
            .environmentObject(root)
            .embeddedInHostingController()

        root.closeCurrentSheet
            .sink { [weak hosting] _ in
                hosting?.dismiss(animated: true)
            }
            .store(in: &cancellables)

        rootViewController?.present(hosting, animated: true)
    }

    func openSharingConfiguration(for id: PhotoId, type: SharingConfigType) {
        guard
            dependencies.featureFlagsController.hasSharing,
            let rootViewController
        else { return }
        GalleryScenesFactory()
            .makeNewShareViewController(
                identifier: id,
                tower: dependencies.tower,
                storage: dependencies.storage,
                contactsManager: dependencies.contactsManager,
                featureFlagsController: dependencies.featureFlagsController,
                rootViewController: rootViewController,
                sharingMemberFactory: dependencies.sharingMemberFactory
            )?.openSharingConfig(sharingType: type)
    }

    func openShareToSheet(selectionController: PhotosSelectionController, isDownloaded: Bool) {
        let type: GroupToAlbumSheetType = isDownloaded ? .shareTo : .shareToWithoutNativeShare
        groupToAlbumController.presentActionSheet(type: type, selectionController: selectionController)
    }

    func presentGroupToAlbumActionSheet(selectionController: PhotosSelectionController) {
        groupToAlbumController.presentActionSheet(type: .groupToAlbum, selectionController: selectionController)
    }
}

extension PhotosPreviewActionCoordinator {
    struct Dependencies {
        let contactsManager: ContactsManagerProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let sharingMemberFactory: SharingMemberStartFactoryProtocol
        let tower: Tower
        var storage: StorageManager { tower.storage }
    }
}
