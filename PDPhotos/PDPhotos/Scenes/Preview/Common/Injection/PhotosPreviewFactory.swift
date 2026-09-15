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

import Combine
import CoreData
import PDCore
import PDCoreIOS
import UIKit

struct PhotosPreviewFactory {
    func makeCoordinator(container: PhotosPreviewContainer) -> PhotosPreviewCoordinator {
        PhotosPreviewCoordinator(container: container)
    }

    // swiftlint:disable:next function_parameter_count
    func makePreviewViewController(
        coordinator: PhotosPreviewCoordinator,
        previewController: PhotosPreviewController,
        listController: PhotosListControllerProtocol,
        modeController: PhotosPreviewModeController,
        detailController: PhotoPreviewCurrentDetailController,
        actionViewModel: PhotosPreviewActionViewModel
    ) -> UIViewController {
        let viewModel = PhotosPreviewViewModel(
            controller: previewController,
            coordinator: coordinator,
            modeController: modeController,
            detailController: detailController,
            actionViewModel: actionViewModel
        )

        let actionController = PhotosPreviewActionView(viewModel: actionViewModel).embeddedInHostingController()
        let viewController = PhotosPreviewViewController(
            viewModel: viewModel,
            actionViewModel: actionViewModel,
            factory: coordinator,
            actionViewController: actionController
        )
        actionViewModel.dependencies.coordinator.set(rootViewController: viewController)
        actionViewModel.dependencies.nativeSharePhotoController.coordinator.set(rootViewController: viewController)
        coordinator.rootViewController = viewController
        return UINavigationController(rootViewController: viewController)
    }

    // swiftlint:disable:next function_parameter_count
    func makeDetailViewController(
        id: PhotoId,
        albumId: AlbumIdentifier?,
        tower: Tower,
        coordinator: PhotosPreviewCoordinator,
        photoThumbnailDownloader: SDKThumbnailsDownloaderProtocol,
        modeController: PhotosPreviewModeController,
        previewController: PhotosPreviewController,
        detailController: PhotoPreviewDetailController,
        photosManagedObjectContext: NSManagedObjectContext,
        photoUploadedNotifier: PhotoUploadedNotifier,
        metadataController: MetadataControllerProtocol,
        performanceMetricsController: PerformanceMetricsControllerProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol,
        fileIsDownloadedSubject: PassthroughSubject<PhotoId, Never>
    ) -> UIViewController {
        let fileContentController = GalleryScenesFactory().makeFileContentController(
            tower: tower,
            featureFlagsController: featureFlagsController,
            moc: photosManagedObjectContext,
            photoUploadedNotifier: photoUploadedNotifier
        )
        let fullPreviewController = LocalPhotoFullPreviewController(
            id: id,
            buildType: Constants.buildType,
            detailController: detailController,
            photoThumbnailDownloader: photoThumbnailDownloader,
            contentController: fileContentController,
            messageHandler: UserMessageHandler()
        )
        let shareController = CachingPhotoPreviewDetailShareController(fileContentController: fileContentController, coordinator: coordinator, id: id)
        let videoXAttrBackfiller = makeVideoXAttrBackfiller(tower: tower, id: id, managedContext: photosManagedObjectContext)
        let viewModel = PhotoPreviewDetailViewModel(
            photoThumbnailDownloader: photoThumbnailDownloader,
            modeController: modeController,
            previewController: previewController,
            detailController: detailController,
            fullPreviewController: fullPreviewController,
            shareController: shareController,
            id: id,
            coordinator: coordinator,
            metadataController: metadataController,
            videoXAttrBackfiller: videoXAttrBackfiller,
            performanceMetricsController: performanceMetricsController,
            fileIsDownloadedSubject: fileIsDownloadedSubject
        )
        let loadingViewController = makeLoadingView(fullPreviewController: fullPreviewController)
        return PhotoPreviewDetailViewController(viewModel: viewModel, loadingViewController: loadingViewController)
    }

    private func makeVideoXAttrBackfiller(
        tower: Tower,
        id: PhotoId,
        managedContext: NSManagedObjectContext
    ) -> VideoXAttrBackfiller {
        let exifResource = CoreImagePhotoLibraryExifResource(parser: CoreImagePhotoLibraryExifParser())
        let analyzer = DefaultXAttrBackfillAnalyzer(exifResource: exifResource)
        let backfiller = DefaultPhotoXAttrBatchBackfiller(
            client: tower.client,
            encryptor: Encryptor(),
            managedContext: managedContext,
            signersKitFactory: tower.sessionVault
        )
        return VideoXAttrBackfiller(
            dependencies: .init(
                analyzer: analyzer,
                backfiller: backfiller,
                exifResource: exifResource,
                revisionReader: PhotoRevisionReader(),
                managedContext: managedContext
            ),
            id: id
        )
    }

    private func makeLoadingView(fullPreviewController: PhotoFullPreviewController) -> UIViewController {
        let controller = PhotoPreviewLoadingStateController(previewController: fullPreviewController, debounceResource: CommonLoopDebounceResource())
        let viewModel = PhotoPreviewLoadingStateViewModel(controller: controller)
        let view = PhotoPreviewLoadingStateView(viewModel: viewModel)
        return view.embeddedInTransparentHostingController()
    }

    func makePreviewController(listController: PhotosListControllerProtocol, currentId: PhotoId) -> PhotosPreviewController {
        ListingPhotosPreviewController(controller: listController, currentId: currentId)
    }

    func makeModeController() -> PhotosPreviewModeController {
        GalleryPhotosPreviewModeController()
    }

    func makeDetailController(tower: Tower, currentDetailController: PhotoPreviewCurrentDetailController) -> PhotoPreviewDetailController {
        let observerFactory = PhotoInfoObserverFactory()
        let repository = DatabasePhotoInfoRepository(observerFactory: observerFactory, managedObjectContext: tower.storage.photosSecondaryBackgroundContext)
        return LocalPhotoPreviewDetailController(repository: repository, currentDetailController: currentDetailController)
    }

    func makeCurrentDetailController(previewController: PhotosPreviewController) -> PhotoPreviewCurrentDetailController {
        LocalPhotoPreviewCurrentDetailController(previewController: previewController)
    }
}
