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
import PDCore
import UIKit

final class PhotosPreviewContainer {
    struct Dependencies {
        let id: PhotoId
        let tower: Tower
        let galleryController: PhotosGalleryController
        let smallThumbnailsController: ThumbnailsController
        let bigThumbnailsController: ThumbnailsController
    }

    private let dependencies: Dependencies
    private let previewController: PhotosPreviewController
    private let modeController: PhotosPreviewModeController
    private let currentDetailController: PhotoPreviewCurrentDetailController
    private weak var coordinator: PhotosPreviewCoordinator?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let factory = PhotosPreviewFactory()
        previewController = factory.makePreviewController(galleryController: dependencies.galleryController, currentId: dependencies.id)
        modeController = factory.makeModeController()
        currentDetailController = factory.makeCurrentDetailController(previewController: previewController)
    }

    func makeRootViewController(with id: PhotoId) -> UIViewController {
        let factory = PhotosPreviewFactory()
        let coordinator = factory.makeCoordinator(container: self)
        self.coordinator = coordinator
        return factory.makePreviewViewController(
            coordinator: coordinator,
            previewController: previewController,
            galleryController: dependencies.galleryController,
            modeController: modeController,
            detailController: currentDetailController
        )
    }

    func makeDetailViewController(with id: PhotoId) -> UIViewController {
        let factory = PhotosPreviewFactory()
        let coordinator = coordinator ?? factory.makeCoordinator(container: self)
        let detailController = factory.makeDetailController(tower: dependencies.tower, currentDetailController: currentDetailController)
        return factory.makeDetailViewController(
            id: id,
            tower: dependencies.tower,
            coordinator: coordinator,
            smallThumbnailsController: dependencies.smallThumbnailsController,
            bigThumbnailsController: dependencies.bigThumbnailsController,
            modeController: modeController,
            previewController: previewController,
            detailController: detailController
        )
    }
}
