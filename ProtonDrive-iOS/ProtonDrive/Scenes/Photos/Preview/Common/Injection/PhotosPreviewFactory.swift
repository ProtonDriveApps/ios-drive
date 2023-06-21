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

import PDCore
import UIKit

struct PhotosPreviewFactory {
    func makeCoordinator(container: PhotosPreviewContainer) -> PhotosPreviewCoordinator {
        PhotosPreviewCoordinator(container: container)
    }

    func makePreviewViewController(
        coordinator: PhotosPreviewCoordinator,
        previewController: PhotosPreviewController,
        galleryController: PhotosGalleryController,
        modeController: PhotosPreviewModeController,
        detailController: PhotoPreviewCurrentDetailController
    ) -> UIViewController {
        let viewModel = PhotosPreviewViewModel(controller: previewController, coordinator: coordinator, modeController: modeController, detailController: detailController)
        let viewController = PhotosPreviewViewController(viewModel: viewModel, factory: coordinator)
        coordinator.rootViewController = viewController
        return UINavigationController(rootViewController: viewController)
    }

    // swiftlint:disable:next function_parameter_count
    func makeDetailViewController(
        id: PhotoId,
        tower: Tower,
        coordinator: PhotosPreviewCoordinator,
        smallThumbnailsController: ThumbnailsController,
        bigThumbnailsController: ThumbnailsController,
        modeController: PhotosPreviewModeController,
        previewController: PhotosPreviewController,
        detailController: PhotoPreviewDetailController
    ) -> UIViewController {
        let smallThumbnailController = LocalThumbnailController(thumbnailsController: smallThumbnailsController, id: id)
        let fullThumbnailController = LocalThumbnailController(thumbnailsController: bigThumbnailsController, id: id)
        let contentController = LocalFileContentController(resource: DecryptedFileContentResource(storage: tower.storage, downloader: tower.downloader))
        let fullPreviewController = LocalPhotoFullPreviewController(detailController: detailController, thumbnailController: fullThumbnailController, contentController: contentController)
        let viewModel = PhotoPreviewDetailViewModel(thumbnailController: smallThumbnailController, modeController: modeController, previewController: previewController, detailController: detailController, fullPreviewController: fullPreviewController, id: id, coordinator: coordinator)
        return PhotoPreviewDetailViewController(viewModel: viewModel)
    }

    func makePreviewController(galleryController: PhotosGalleryController, currentId: PhotoId) -> PhotosPreviewController {
        ListingPhotosPreviewController(controller: galleryController, currentId: currentId)
    }

    func makeModeController() -> PhotosPreviewModeController {
        GalleryPhotosPreviewModeController()
    }

    func makeDetailController(tower: Tower, currentDetailController: PhotoPreviewCurrentDetailController) -> PhotoPreviewDetailController {
        LocalPhotoPreviewDetailController(repository: DatabasePhotoInfoRepository(storage: tower.storage), currentDetailController: currentDetailController)
    }

    func makeCurrentDetailController(previewController: PhotosPreviewController) -> PhotoPreviewCurrentDetailController {
        LocalPhotoPreviewCurrentDetailController(previewController: previewController)
    }
}
