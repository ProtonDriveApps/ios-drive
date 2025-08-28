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

import Combine
import PDCore
import PDCoreIOS
import PDLocalization

@MainActor
final class AlbumCreationViewModel: ObservableObject {
    @Published private(set) var canBeSaved: Bool = false
    @Published private(set) var isProcessing = false
    @Published private(set) var isSelecting = false
    @Published private(set) var photosViewModel: PhotoListingGridViewModel
    @Published var albumName = ""
    private let dependencies: Dependencies
    private let shouldOpenInvitation: Bool
    private let volumeID: String
    private var cancellables = Set<AnyCancellable>()
    private var photoListing: [PhotoListing] = []

    /// - Parameters:
    ///   - data: Editing album data
    init(dependencies: Dependencies, shouldOpenInvitation: Bool, volumeID: String, photoIDs: Set<PhotoListingId> = []) {
        self.dependencies = dependencies
        self.shouldOpenInvitation = shouldOpenInvitation
        self.volumeID = volumeID
        self.photosViewModel = .init(sections: [], didShowLastItemBlock: {})
        if !photoIDs.isEmpty {
            handleSelectionFinalized(ids: photoIDs)
        }
        subscribeToUpdates()
    }

    func tapAddButton() {
        let ids = photoListing.map { PhotoListingId(primary: $0.id, secondary: $0.secondaryPhotos) }
        dependencies.addPhotoSelectionController.deselectAll()
        dependencies.addPhotoSelectionController.start(selectedID: Set(ids))
        dependencies.coordinator.openPhotoPicker(selectionController: dependencies.addPhotoSelectionController)
    }

    func tapRemovePhotos() {
        let primaryIDs = dependencies.removeSelectionController.getPrimaryIds()
        for id in primaryIDs {
            photoListing.removeAll(where: { $0.id == id })
        }
        updatePhotosViewModel()
        dependencies.removeSelectionController.cancel()
    }

    func tapDone() {
        guard !isProcessing else { return }
        do {
            albumName = try albumName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .validateNodeName(validator: NameValidations.iosName)
            isProcessing = true
            createAlbum()
        } catch {
            dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
    }

    func makeItemViewModel(from item: PhotoGridViewItem) -> PhotoItemViewModel {
        dependencies.itemViewModelFactory.makeViewModel(for: item)
    }
}

extension AlbumCreationViewModel {
    private func subscribeToUpdates() {
        dependencies.removeSelectionController.updatePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                isSelecting = dependencies.removeSelectionController.isSelecting()
            }
            .store(in: &cancellables)

        dependencies.addPhotoSelectionController.finalizedPublisher
            .sink { [weak self] ids in
                self?.handleSelectionFinalized(ids: ids)
            }
            .store(in: &cancellables)

        $albumName
            .sink { [weak self] newName in
                self?.canBeSaved = !newName.isEmpty
            }
            .store(in: &cancellables)
    }

    private func handleSelectionFinalized(ids: Set<PhotoListingId>) {
        Task {
            let primaryIDs = ids.map(\.primary)
            let listings = await dependencies.photoListingsLoadRepository.execute(identifiers: primaryIDs)
            photoListing = listings
            updatePhotosViewModel()
        }
        dependencies.coordinator.dismissPicker()
    }

    private func updatePhotosViewModel() {
        let items = photoListing.map { data in
            var metadata: PhotoGridViewItem.Metadata?
            if let listingMetadata = data.metadata {
                metadata = .init(
                    isShared: listingMetadata.isShared,
                    hasDirectShare: listingMetadata.hasDirectShare,
                    isVideo: listingMetadata.isVideo,
                    isDownloading: listingMetadata.isDownloading,
                    isAvailableOffline: listingMetadata.isAvailableOffline,
                    burstChildrenCount: listingMetadata.burstChildrenCount,
                    isFavorite: listingMetadata.isFavorite
                )
            }
            return PhotoGridViewItem(
                photoId: data.id.id,
                secondaryIds: data.secondaryPhotos.map(\.id),
                volumeId: data.id.volumeID,
                albumId: nil, // Album id not known atm. No impact to set it nil in creation
                captureTime: data.captureTime,
                metadata: metadata
            )
        }
        photosViewModel = .init(sections: [.init(items: items)], didShowLastItemBlock: {})
    }

    private func makeCreateAlbumParameters() -> CreateAlbumController.Parameters {
        return .init(clearAlbumName: albumName, photoIDs: photoListing.map(\.id))
    }

    private func createAlbum() {
        let parameters = makeCreateAlbumParameters()
        Task {
            let result = await dependencies.createAlbumController.execute(parameters: parameters)
            switch result {
            case .createAlbumFailed(let error):
                Log.error(error: error, domain: .albums)
                // TODO:album user friendly message?
                dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
            case .addPhotosFailed(let albumID, let error):
                dependencies.eventsSystemManager.forcePolling(volumeIDs: [volumeID])
                dependencies.coordinator.showAlbumDetail(albumID: albumID, shouldOpenInvitation: shouldOpenInvitation)
                // Add photo error
                dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
            case let .success(albumID, result):
                dependencies.coordinator.showAlbumDetail(albumID: albumID, shouldOpenInvitation: shouldOpenInvitation)
                dependencies.eventsSystemManager.forcePolling(volumeIDs: [volumeID])
                dependencies.albumContentOperationMessenger.showAddPhotosBanner(for: result)
            }

            isProcessing = false
        }
    }
}

extension AlbumCreationViewModel {
    struct Dependencies {
        let addPhotoSelectionController: PhotosSelectionController
        let albumContentOperationMessenger: PhotosMoveOperationMessageHandlerProtocol
        let coordinator: AlbumCreationCoordinator
        let createAlbumController: CreateAlbumControllerProtocol
        let eventsSystemManager: EventsSystemManager
        let removeSelectionController: PhotosSelectionController
        let itemViewModelFactory: CachingPhotoItemViewModelFactoryProtocol
        let photoListingsLoadRepository: PhotoListingsLoadRepositoryProtocol
        let userMessageHandler: UserMessageHandlerProtocol

        init(
            addPhotoSelectionController: PhotosSelectionController,
            albumContentOperationMessenger: PhotosMoveOperationMessageHandlerProtocol? = nil,
            coordinator: AlbumCreationCoordinator,
            createAlbumController: CreateAlbumControllerProtocol,
            eventsSystemManager: EventsSystemManager,
            removeSelectionController: PhotosSelectionController,
            itemViewModelFactory: CachingPhotoItemViewModelFactoryProtocol,
            photoListingsLoadRepository: PhotoListingsLoadRepositoryProtocol,
            userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
        ) {
            self.addPhotoSelectionController = addPhotoSelectionController
            self.albumContentOperationMessenger = albumContentOperationMessenger ?? AlbumContentOperationMessenger(userMessageHandler: userMessageHandler)
            self.coordinator = coordinator
            self.createAlbumController = createAlbumController
            self.eventsSystemManager = eventsSystemManager
            self.removeSelectionController = removeSelectionController
            self.itemViewModelFactory = itemViewModelFactory
            self.photoListingsLoadRepository = photoListingsLoadRepository
            self.userMessageHandler = userMessageHandler
        }
    }

    struct AlbumData {
        let name: String
        let photoListing: [PhotoListing]
    }
}
