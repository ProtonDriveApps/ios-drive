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

import CoreData
import Foundation
import PDCore
import PDCoreIOS
import UIKit

final class PhotosPreviewContainer {
    struct Dependencies {
        let id: PhotoId
        let tower: Tower
        let listController: PhotosListControllerProtocol
        let thumbnailsContainer: ThumbnailsControllersContainer
        let photosManagedObjectContext: NSManagedObjectContext
        let photoUploadedNotifier: PhotoUploadedNotifier
        let metadataController: MetadataControllerProtocol
        let offlineAvailableResource: OfflineAvailableResource
        let parentDependencies: GallerySceneContainer.Dependencies
    }

    let dependencies: Dependencies
    let gallerySceneContainer: GallerySceneContainer
    private let streamConfiguration: PhotoStreamConfiguration
    private let previewController: PhotosPreviewController
    private let modeController: PhotosPreviewModeController
    private let currentDetailController: PhotoPreviewCurrentDetailController
    private weak var coordinator: PhotosPreviewCoordinator?

    init(dependencies: Dependencies, gallerySceneContainer: GallerySceneContainer) {
        self.dependencies = dependencies
        self.gallerySceneContainer = gallerySceneContainer
        self.streamConfiguration = gallerySceneContainer.streamConfiguration
        let factory = PhotosPreviewFactory()
        previewController = factory.makePreviewController(listController: dependencies.listController, currentId: dependencies.id)
        modeController = factory.makeModeController()
        currentDetailController = factory.makeCurrentDetailController(previewController: previewController)
    }

    func makeRootViewController(with id: PhotoId, albumID: AlbumIdentifier?) -> UIViewController {
        let factory = PhotosPreviewFactory()
        let coordinator = factory.makeCoordinator(container: self)
        self.coordinator = coordinator
        return factory.makePreviewViewController(
            coordinator: coordinator,
            previewController: previewController,
            listController: dependencies.listController,
            modeController: modeController,
            detailController: currentDetailController,
            actionViewModel: makePhotosPreviewActionViewModel(
                rootPhotoID: id,
                streamConfiguration: streamConfiguration,
                albumID: albumID
            )
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
            thumbnailsContainer: dependencies.thumbnailsContainer,
            modeController: modeController,
            previewController: previewController,
            detailController: detailController,
            photosManagedObjectContext: dependencies.photosManagedObjectContext,
            photoUploadedNotifier: dependencies.photoUploadedNotifier,
            metadataController: dependencies.metadataController
        )
    }

    func makePhotosPreviewActionViewModel(
        rootPhotoID: PhotoId,
        streamConfiguration: PhotoStreamConfiguration,
        albumID: AlbumIdentifier?
    ) -> PhotosPreviewActionViewModel {
        let factory = GalleryScenesFactory()
        let tower = dependencies.tower
        let context = dependencies.parentDependencies.managedObjectContext

        let offlineAvailableController = UpdatingOfflineAvailableController(
            resource: dependencies.offlineAvailableResource
        )

        let trashDialogFactory = factory.makeTrashDialogFactory(
            albumID: albumID,
            context: context,
            selectionController: nil,
            tower: tower
        )

        let copyToStreamController = albumID.map { albumId in
            CopyPhotosControllerFactory().makeCopyPhotosController(
                tower: tower,
                context: context,
                albumId: albumId
            )
        }
        let previewActionVM = PhotosPreviewActionViewModel(
            dependencies: .init(
                coordinator: makePreviewActionCoordinator(),
                favoritingController: factory.makeFavoritingController(tower: tower, managedObjectContext: context),
                featureFlagsController: dependencies.parentDependencies.parentDependencies.featureFlagsController,
                infoReader: PhotosPreviewItemInfoReader(
                    context: dependencies.parentDependencies.managedObjectContext,
                    storageManager: tower.storage
                ),
                metadataController: dependencies.metadataController,
                nativeSharePhotoController: makeNativeSharePhotoController(),
                offlineAvailableController: offlineAvailableController,
                streamConfiguration: streamConfiguration,
                trashDialogFactory: trashDialogFactory,
                userMessageHandler: UserMessageHandler(),
                copyToStreamController: copyToStreamController,
                updateAlbumInteractor: makeUpdateAlbumInteractor(albumID: albumID, context: context, tower: tower)
            ),
            rootPhotoID: rootPhotoID,
            albumID: albumID
        )
        return previewActionVM
    }

    private func makeNativeSharePhotoController() -> NativeSharePhotoController {
        let factory = GalleryScenesFactory()
        let tower = dependencies.tower
        let context = dependencies.parentDependencies.managedObjectContext

        let fileContentController = factory.makeFileContentController(
            tower: tower,
            moc: context,
            photoUploadedNotifier: dependencies.parentDependencies.parentDependencies.photoUploadedNotifier
        )

        return NativeSharePhotoController(
            coordinator: NativeSharePhotoCoordinator(rootViewController: nil),
            fileContentController: fileContentController
        )
    }

    private func makePreviewActionCoordinator() -> PhotosPreviewActionCoordinator {
        return .init(
            dependencies: .init(
                contactsManager: dependencies.parentDependencies.parentDependencies.contactsManager,
                featureFlagsController: dependencies.parentDependencies.parentDependencies.featureFlagsController,
                sharingMemberFactory: dependencies.parentDependencies.parentDependencies.sharingMemberFactory,
                tower: dependencies.tower
            ),
            gallerySceneContainer: gallerySceneContainer
        )
    }

    private func makeUpdateAlbumInteractor(
        albumID: AlbumIdentifier?,
        context: NSManagedObjectContext,
        tower: Tower
    ) -> UpdateAlbumInteractor? {
        if albumID == nil { return nil }
        let provider = PhotoRootInfoProvider(
            dependencies: .init(
                managedObjectContext: context,
                storageManager: tower.storage
            )
        )
        return UpdateAlbumInteractor(
            dependencies: .init(
                client: tower.client,
                managedObjectContext: context,
                photoRootInfoProvider: provider,
                signersKitFactory: tower.sessionVault,
                requestFactory: UpdateAlbumRequestFactory(
                    managedObjectContext: context,
                    encryptionResource: Encryptor(),
                    signersKitFactory: tower.sessionVault
                )
            )
        )
    }
}
