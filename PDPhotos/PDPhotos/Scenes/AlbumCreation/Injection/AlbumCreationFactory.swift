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
import SwiftUI
import UIKit

struct AlbumCreationFactory {
    @MainActor
    func makeAlbumCreationView(
        container: PDPhotosContainer,
        rootViewController: UIViewController?,
        selectedPhotoIDs: Set<PhotoListingId> = [],
        shouldOpenInvitation: Bool = false
    ) -> UIViewController? {
        guard let gallerySceneContainer = container.sceneContainer.gallerySceneContainer else { return nil }

        let coordinator = AlbumCreationCoordinator(container: container, rootViewController: rootViewController)
        let context = container.sceneContainer.dependencies.managedObjectContext
        let mimeTypeResource = CachingMimeTypeResource()
        let repository = PhotoListingsLoadRepository(
            managedObjectContext: context,
            mimeTypeResource: mimeTypeResource
        )

        let factory = AlbumGalleryFactory()
        let removeSelectionController = LocalPhotosSelectionController()
        let itemFactory = factory.makeItemViewModelFactory(
            fetchingController: factory.makeFetchingController(
                id: .init(id: "", volumeID: ""),
                managedObjectContext: context,
                tower: container.dependencies.tower,
                anchorController: gallerySceneContainer.anchorController,
                errorController: container.dependencies.legacyShareErrorController
            ),
            container: gallerySceneContainer,
            selectionController: removeSelectionController,
            rootViewController: rootViewController
        )
        let controller = factory.makeCreateAlbumController(
            managedObjectContext: context,
            tower: gallerySceneContainer.dependencies.tower,
            volumeID: gallerySceneContainer.volumeId
        )
        let viewModel = AlbumCreationViewModel(
            dependencies: .init(
                addPhotoSelectionController: LocalPhotosSelectionController(),
                coordinator: coordinator,
                createAlbumController: controller,
                eventsSystemManager: container.dependencies.tower,
                removeSelectionController: removeSelectionController,
                itemViewModelFactory: itemFactory,
                photoListingsLoadRepository: repository
            ),
            shouldOpenInvitation: shouldOpenInvitation,
            volumeID: gallerySceneContainer.volumeId,
            photoIDs: selectedPhotoIDs
        )
        let view = AlbumCreationView(viewModel: viewModel)
        return UIHostingController(rootView: view)
    }
}
