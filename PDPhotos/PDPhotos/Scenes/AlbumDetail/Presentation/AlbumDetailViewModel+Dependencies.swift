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
import Foundation
import PDCore
import PDCoreIOS

extension AlbumDetailViewModel {
    struct Dependencies {
        let addPhotoSelectionController: PhotosSelectionController
        let addToAlbumController: AddPhotosToAlbumControllerProtocol
        let albumLeaveFlowController: AlbumLeaveFlowControllerProtocol
        let albumRepository: AlbumRepositoryProtocol
        let coordinator: AlbumDetailCoordinatorProtocol
        let contentController: FileContentController
        let dateFormatter: DateFormatter
        let deletionFlowController: AlbumDeletionFlowControllerProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let inviteeListLoadController: InviteeListLoadControllerProtocol
        let itemViewModelFactory: CachingPhotoItemViewModelFactoryProtocol
        let metadataController: MetadataControllerProtocol
        let photosGridViewModel: any PhotosGridViewModelProtocol
        let selectionController: PhotosSelectionController
        let thumbnailDownloader: SDKThumbnailsDownloaderProtocol?
        let userMessageHandler: UserMessageHandlerProtocol
        let copyToStreamController: CopyPhotosToStreamControllerProtocol

        init(
            addPhotoSelectionController: PhotosSelectionController,
            addToAlbumController: AddPhotosToAlbumControllerProtocol,
            albumLeaveFlowController: AlbumLeaveFlowControllerProtocol,
            albumRepository: AlbumRepositoryProtocol,
            coordinator: AlbumDetailCoordinatorProtocol,
            contentController: FileContentController,
            deletionFlowController: AlbumDeletionFlowControllerProtocol,
            featureFlagsController: FeatureFlagsControllerProtocol,
            inviteeListLoadController: InviteeListLoadControllerProtocol,
            itemViewModelFactory: CachingPhotoItemViewModelFactoryProtocol,
            metadataController: MetadataControllerProtocol,
            photosGridViewModel: any PhotosGridViewModelProtocol,
            selectionController: PhotosSelectionController,
            thumbnailDownloader: SDKThumbnailsDownloaderProtocol?,
            userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler(),
            copyToStreamController: CopyPhotosToStreamControllerProtocol
        ) {
            self.addPhotoSelectionController = addPhotoSelectionController
            self.addToAlbumController = addToAlbumController
            self.albumRepository = albumRepository
            self.albumLeaveFlowController = albumLeaveFlowController
            self.coordinator = coordinator
            self.contentController = contentController
            self.dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMM yyyy"
            self.deletionFlowController = deletionFlowController
            self.featureFlagsController = featureFlagsController
            self.inviteeListLoadController = inviteeListLoadController
            self.itemViewModelFactory = itemViewModelFactory
            self.metadataController = metadataController
            self.photosGridViewModel = photosGridViewModel
            self.selectionController = selectionController
            self.userMessageHandler = userMessageHandler
            self.thumbnailDownloader = thumbnailDownloader
            self.copyToStreamController = copyToStreamController
        }
    }

    enum NavigationItem {
        case deselectAll
        case more
        case cancel
        case back
        case empty
    }

    enum Errors: Error {
        case incorrectState
    }
}
