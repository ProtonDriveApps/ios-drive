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
import PDCoreIOS
import PDUIComponents
import SwiftUI
import UIKit

protocol GroupToAlbumSheetPresenterProtocol {
    func presentActionSheet(
        type: GroupToAlbumSheetType,
        selectionController: PhotosSelectionController
    )
}

final class GroupToAlbumSheetPresenter: GroupToAlbumSheetPresenterProtocol {
    private let dependencies: Dependencies
    private var rootViewController: UIViewController?

    init(dependencies: Dependencies, rootViewController: UIViewController?) {
        self.dependencies = dependencies
        self.rootViewController = rootViewController
    }

    func presentActionSheet(
        type: GroupToAlbumSheetType,
        selectionController: PhotosSelectionController
    ) {
        guard let rootViewController else {
            assert(false)
            return
        }
        let selectedPhotoIDs = selectionController.getPhotoListingIDs()
        switch type {
        case .groupToAlbum:
            let sheet = makeGroupToAlbumSheet(
                selectedPhotoIDs: selectedPhotoIDs,
                selectionController: selectionController
            )
            rootViewController.present(sheet, animated: false)
        case .shareTo:
            let sheet = makeShareToSheet(
                selectedPhotoIDs: selectedPhotoIDs,
                selectionController: selectionController
            )
            rootViewController.present(sheet, animated: false)
        }
    }

    private func makeGroupToAlbumSheet(
        selectedPhotoIDs: Set<PhotoListingId>,
        selectionController: PhotosSelectionController
    ) -> UIViewController {

        let sheet = GroupToAlbumActionSheet(
            viewModel: makeGroupToAlbumViewModel(
                albumList: albumListing(tag: nil),
                selectionController: selectionController,
                selectedPhotoIDs: selectedPhotoIDs,
                type: .groupToAlbum
            )
        )

        let host = SheetContainer(contentView: sheet).embeddedInHostingController()
        host.modalPresentationStyle = .overFullScreen
        host.view.backgroundColor = .clear
        return host
    }

    private func makeShareToSheet(
        selectedPhotoIDs: Set<PhotoListingId>,
        selectionController: PhotosSelectionController
    ) -> UIViewController {

        let sheet = ShareToActionSheet(
            viewModel: makeGroupToAlbumViewModel(
                albumList: albumListing(tag: .shared) + albumListing(tag: .sharedWithMe),
                selectionController: selectionController,
                selectedPhotoIDs: selectedPhotoIDs,
                type: .shareTo
            )
        )
        let host = SheetContainer(contentView: sheet).embeddedInHostingController()
        host.modalPresentationStyle = .overFullScreen
        host.view.backgroundColor = .clear
        return host
    }

    private func albumListing(tag: AlbumTag?) -> [AlbumListing] {
        do {
            let albumListing = try dependencies.albumListController.getListings(albumTag: tag)
            return albumListing
        } catch {
            Log.error("Load local album listing failed", error: error, domain: .albums)
            return []
        }
    }

    private func makeGroupToAlbumViewModel(
        albumList: [AlbumListing],
        selectionController: PhotosSelectionController,
        selectedPhotoIDs: Set<PhotoListingId>,
        type: GroupToAlbumSheetType
    ) -> GroupToAlbumActionSheetViewModel {
        return GroupToAlbumActionSheetViewModel(
            albumList: albumList,
            dependencies: .init(
                addPhotosController: dependencies.addPhotosController,
                albumGridItemViewModelFactory: dependencies.albumGridItemViewModelFactory,
                coordinator: dependencies.coordinator,
                nativeSharePhotoController: dependencies.nativeSharePhotoController,
                selectionController: selectionController
            ),
            metadataController: dependencies.metadataController,
            selectedPhotoIDs: selectedPhotoIDs,
            thumbnailContainer: dependencies.thumbnailContainer,
            type: type
        )
    }

}

extension GroupToAlbumSheetPresenter {
    struct Dependencies {
        let addPhotosController: AddPhotosToAlbumControllerProtocol
        let albumListController: LocalAlbumListControllerProtocol
        let albumGridItemViewModelFactory: CachingAlbumGridItemViewModelFactoryProtocol
        let context: NSManagedObjectContext
        let coordinator: GroupToAlbumCoordinatorProtocol
        let metadataController: MetadataControllerProtocol
        let nativeSharePhotoController: NativeSharePhotoControllerProtocol
        let thumbnailContainer: ThumbnailsControllersContainerProtocol

        init(
            addPhotosController: AddPhotosToAlbumControllerProtocol,
            albumListController: LocalAlbumListControllerProtocol,
            context: NSManagedObjectContext,
            coordinator: GroupToAlbumCoordinatorProtocol,
            metadataController: MetadataControllerProtocol,
            nativeSharePhotoController: NativeSharePhotoControllerProtocol,
            thumbnailContainer: ThumbnailsControllersContainerProtocol
        ) {
            self.addPhotosController = addPhotosController
            self.albumListController = albumListController
            self.context = context
            self.coordinator = coordinator
            self.metadataController = metadataController
            self.nativeSharePhotoController = nativeSharePhotoController
            self.thumbnailContainer = thumbnailContainer

            self.albumGridItemViewModelFactory = CachingAlbumGridItemViewModelFactory(factory: { id in
                let repository = AlbumRepository(albumID: id, managedObjectContext: context)
                return .init(
                    albumID: id,
                    albumRepository: repository,
                    debounceResource: CommonLoopDebounceResource(),
                    metadataController: metadataController,
                    thumbnailContainer: thumbnailContainer
                )
            })
        }
    }
}

enum GroupToAlbumSheetType {
    case groupToAlbum
    case shareTo
}
