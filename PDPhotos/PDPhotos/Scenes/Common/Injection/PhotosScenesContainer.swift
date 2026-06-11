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

import CoreData
import PDCore
import SwiftUI

// Container holding anything that needs retaining as long as either Photos or Albums exist
final class PhotosScenesContainer {
    struct Dependencies {  // TODO: `Albums` related: refactor if possible into standalone struct without coupling with parent
        let parentDependencies: PDPhotosContainer.Dependencies
        let managedObjectContext: NSManagedObjectContext
        var tower: Tower { parentDependencies.tower }
    }
    let dependencies: Dependencies
    let metadataController: MetadataControllerProtocol
    let streamThumbnailsContainer: ThumbnailsControllersContainer
    let albumsThumbnailsContainer: ThumbnailsControllersContainer
    let screenLockController: ScreenLockController
    private(set) weak var parent: PDPhotosContainer?
    private(set) var gallerySceneContainer: GallerySceneContainer?
    let galleryTagsController: GalleryTagsController

    init(parent: PDPhotosContainer) {
        self.parent = parent
        let context = parent.dependencies.tower.storage.photosSecondaryBackgroundContext
        dependencies = Dependencies(
            parentDependencies: parent.dependencies,
            managedObjectContext: context
        )
        let factory = PDPhotosFactory()
        metadataController = factory.makeMetadataController(tower: dependencies.parentDependencies.tower, managedObjectContext: context)
        streamThumbnailsContainer = factory.makeThumbnailsContainer(
            tower: dependencies.parentDependencies.tower,
            metadataController: metadataController,
            performanceMetricsController: dependencies.parentDependencies.performanceMetricsController,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController
        )
        albumsThumbnailsContainer = factory.makeThumbnailsContainer(
            tower: dependencies.parentDependencies.tower,
            metadataController: metadataController,
            performanceMetricsController: dependencies.parentDependencies.performanceMetricsController,
            featureFlagsController: dependencies.parentDependencies.featureFlagsController
        )
        let lockingFactory = LockingBannerFactory()
        screenLockController = lockingFactory.makeController(
            backupNotifier: dependencies.parentDependencies.backupStateController,
            tagMigrationNotifier: dependencies.parentDependencies.photoTagsMigrationController,
            repository: dependencies.parentDependencies.lockBannerRepository
        )
        self.galleryTagsController = GalleryTagsController(featureFlagsController: dependencies.parentDependencies.featureFlagsController, localSettings: dependencies.tower.localSettings)
    }

    func makeAlbumsView(
        configuration: PhotosRootConfiguration,
        streamConfiguration: PhotoStreamConfiguration,
        rootViewController: UIViewController?
    ) -> some View {
        let container = getOrMakeGallerySceneContainer(streamConfiguration: streamConfiguration)
        return container.makeAlbumGallery(
            rootViewController: rootViewController,
            configuration: configuration,
            streamConfiguration: streamConfiguration
        )
    }

    func makeGalleryView(
        configuration: PhotosRootConfiguration,
        rootViewController: UIViewController?,
        selectionController: PhotosSelectionController,
        streamConfiguration: PhotoStreamConfiguration
    ) -> some View {
        let container = getOrMakeGallerySceneContainer(streamConfiguration: streamConfiguration)
        return container.makeMainView(
            rootViewController: rootViewController,
            configuration: configuration,
            selectionController: selectionController,
            screenLockController: screenLockController
        )
    }

    private func getOrMakeGallerySceneContainer(streamConfiguration: PhotoStreamConfiguration) -> GallerySceneContainer {
        if let container = gallerySceneContainer, container.streamConfiguration == streamConfiguration {
            // Return cached container only if photo stream configuration didn't change
            // It changes once legacy share migrates to photo volume, at which point we need to
            // discard the UI and rebuild it from scratch
            return container
        }
        let container = makeGallerySceneContainer(streamConfiguration: streamConfiguration)
        gallerySceneContainer = container
        return container
    }

    private func makeGallerySceneContainer(streamConfiguration: PhotoStreamConfiguration) -> GallerySceneContainer {
        let dependencies = GallerySceneContainer.Dependencies(
            parentDependencies: dependencies.parentDependencies,
            managedObjectContext: dependencies.managedObjectContext,
            metadataController: metadataController,
            streamThumbnailsContainer: streamThumbnailsContainer,
            albumsThumbnailsContainer: albumsThumbnailsContainer,
            tagsController: galleryTagsController
        )
        return GallerySceneContainer(
            dependencies: dependencies,
            streamConfiguration: streamConfiguration,
            parent: self
        )
    }
}
