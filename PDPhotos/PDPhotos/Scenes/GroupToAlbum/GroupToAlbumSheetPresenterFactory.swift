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

struct GroupToAlbumFactory {
    func makePresenter(
        container: GallerySceneContainer,
        rootViewController: UIViewController?
    ) -> GroupToAlbumSheetPresenterProtocol {
        let listController = PDPhotosFactory().makeLocalAlbumListController(
            context: container.dependencies.managedObjectContext,
            storageManger: container.dependencies.tower.storage,
            streamConfiguration: container.streamConfiguration
        )
        let coordinator = GroupToAlbumCoordinator(container: container, rootViewController: rootViewController)
        let addPhotosController = AddPhotosToAlbumControllerFactory().makeController(
            tower: container.dependencies.tower,
            managedObjectContext: container.dependencies.managedObjectContext
        )
        let fileContentController = GalleryScenesFactory().makeFileContentController(
            tower: container.dependencies.tower,
            featureFlagsController: container.dependencies.parentDependencies.featureFlagsController,
            moc: container.dependencies.managedObjectContext,
            photoUploadedNotifier: container.dependencies.parentDependencies.photoUploadedNotifier
        )
        let nativeSharePhotoController = NativeSharePhotoController(
            coordinator: NativeSharePhotoCoordinator(rootViewController: rootViewController),
            fileContentController: fileContentController
        )

        let controller = GroupToAlbumSheetPresenter(
            dependencies: .init(
                addPhotosController: addPhotosController,
                albumListController: listController,
                context: container.dependencies.managedObjectContext,
                coordinator: coordinator,
                metadataController: container.dependencies.metadataController,
                nativeSharePhotoController: nativeSharePhotoController,
                thumbnailContainer: container.dependencies.albumsThumbnailsContainer
            ),
            rootViewController: rootViewController
        )
        return controller
    }
}
