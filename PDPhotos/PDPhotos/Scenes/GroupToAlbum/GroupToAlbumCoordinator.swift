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

protocol GroupToAlbumCoordinatorProtocol {
    func openAlbumCreationView(selectedPhotoIDs: Set<PhotoListingId>, isCreatingSharedAlbum: Bool)
    func openShareConfig(for id: PhotoId)
}

final class GroupToAlbumCoordinator: GroupToAlbumCoordinatorProtocol {
    private let container: GallerySceneContainer
    private weak var rootViewController: UIViewController?
    private var navigationController: UINavigationController? { rootViewController?.navigationController }

    init(container: GallerySceneContainer, rootViewController: UIViewController? = nil) {
        self.container = container
        self.rootViewController = rootViewController
    }

    @MainActor
    func openAlbumCreationView(selectedPhotoIDs: Set<PhotoListingId>, isCreatingSharedAlbum: Bool) {
        guard let rootContainer = container.parent?.parent else { return }
        guard let vc = AlbumCreationFactory().makeAlbumCreationView(
            container: rootContainer,
            rootViewController: rootViewController,
            selectedPhotoIDs: selectedPhotoIDs,
            shouldOpenInvitation: isCreatingSharedAlbum
        ) else { return }
        navigationController?.pushViewController(vc, animated: true)
    }

    func openShareConfig(for id: PhotoId) {
        let featureFlagsController = container.dependencies.parentDependencies.featureFlagsController

        if featureFlagsController.hasSharing, let rootViewController {
            container.makeShareViewController(id: id, rootVC: rootViewController)?.openSharingConfig(sharingType: .common)
        }
    }
}
