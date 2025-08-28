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

final class GroupToAlbumActionSheetViewModel {
    let albumList: [AlbumListing]
    var isSingleSelection: Bool { selectedPhotoIDs.count == 1 }
    private let dependencies: Dependencies
    private let metadataController: MetadataControllerProtocol
    private let selectedPhotoIDs: Set<PhotoListingId>
    private let thumbnailContainer: ThumbnailsControllersContainerProtocol
    private let type: GroupToAlbumSheetType
    private let maximumSheetHeight: CGFloat = 450

    init(
        albumList: [AlbumListing],
        dependencies: Dependencies,
        metadataController: MetadataControllerProtocol,
        selectedPhotoIDs: Set<PhotoListingId>,
        thumbnailContainer: ThumbnailsControllersContainerProtocol,
        type: GroupToAlbumSheetType
    ) {
        self.albumList = albumList
        self.dependencies = dependencies
        self.metadataController = metadataController
        self.selectedPhotoIDs = selectedPhotoIDs
        self.thumbnailContainer = thumbnailContainer
        self.type = type
    }

    private var idealSheetHeight: CGFloat {
        let cellHeight: CGFloat = 64
        switch type {
        case .groupToAlbum:
            return CGFloat(albumList.count + 1) * cellHeight
        case .shareTo:
            let sectionHeight: CGFloat = 52
            let actionNum: CGFloat = isSingleSelection ? 3 : 1
            let actionListHeight: CGFloat = sectionHeight + actionNum * cellHeight
            let albumListHeight: CGFloat = sectionHeight + CGFloat(albumList.count) * cellHeight
            return actionListHeight + albumListHeight
        }
    }

    var sheetHeight: CGFloat {
        min(idealSheetHeight, maximumSheetHeight)
    }

    var canScroll: Bool {
        return idealSheetHeight > maximumSheetHeight
    }

    func makeCellViewModel(for album: AlbumListing) -> AlbumGridItemViewModel {
        dependencies.albumGridItemViewModelFactory.makeViewModel(for: album.id)
    }

    func createAlbum(isCreatingSharedAlbum: Bool) {
        dependencies.selectionController.cancel()
        dependencies.coordinator.openAlbumCreationView(
            selectedPhotoIDs: selectedPhotoIDs,
            isCreatingSharedAlbum: isCreatingSharedAlbum
        )
    }

    func groupToAlbum(identifier: AnyVolumeIdentifier) {
        let primaryIds = Set(selectedPhotoIDs.map(\.primary))
        dependencies.addPhotosController.add(primaryIds: primaryIds, to: identifier)
    }

    func shareViaLink() {
        guard let id = selectedPhotoIDs.first else { return }
        dependencies.coordinator.openShareConfig(for: id.primary)
    }

    func nativeShare() {
        guard let id = selectedPhotoIDs.first else { return }
        dependencies.nativeSharePhotoController.share(id: id.primary)
    }
}

extension GroupToAlbumActionSheetViewModel {
    struct Dependencies {
        let addPhotosController: AddPhotosToAlbumControllerProtocol
        let albumGridItemViewModelFactory: CachingAlbumGridItemViewModelFactoryProtocol
        let coordinator: GroupToAlbumCoordinatorProtocol
        let nativeSharePhotoController: NativeSharePhotoControllerProtocol
        let selectionController: PhotosSelectionController
    }
}
