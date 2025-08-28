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
import Combine
import Foundation
import PDCore
import PDCoreIOS
import PDUIComponents
import PDLocalization

protocol PhotosPreviewActionViewModelProtocol: ObservableObject {
    var actions: PhotosActions { get }
    var currentAction: PhotosAction? { get set }
    var isLoading: Bool { get }
    var dialogModel: DialogSheetModel { get }
    var isCopying: Bool { get }
    func previewIsChanged(item: PhotosPreviewItem)
    func handle(action: PhotosAction)
}

// TODO: There's a lot of duplication in this class with the old PhotosActionViewModel.
// Either extract shared logic or replace `PhotosActionViewModel` with this class
final class PhotosPreviewActionViewModel: PhotosPreviewActionViewModelProtocol {
    @Published private(set) var actions: PhotosActions = .init(primary: [], more: nil)
    @Published private(set) var isLoading: Bool = true
    @Published var currentAction: PhotosAction?
    @Published var shareButtonTitle: String?
    @Published var isCopying: Bool = false
    let dependencies: Dependencies
    private let albumID: AnyVolumeIdentifier?
    private var cancellables = Set<AnyCancellable>()
    private var currentPhotoID: AnyVolumeIdentifier?
    private var isPhotoMetadataLoaded: Bool = false
    private var source: PhotosPreviewSource = .undetermined
    private(set) var dialogModel: DialogSheetModel = .placeholder
    private var photosRootIdentifier: AnyVolumeIdentifier?

    init(dependencies: Dependencies, rootPhotoID: AnyVolumeIdentifier, albumID: AnyVolumeIdentifier?) {
        self.dependencies = dependencies
        self.currentPhotoID = rootPhotoID
        self.albumID = albumID
        subscribeToUpdate()
        setupSource()
        loadMetadata()
    }

    func previewIsChanged(item: PhotosPreviewItem) {
        isLoading = true
        currentPhotoID = item.any()
        loadMetadata()
    }

    private func copySharedPhoto() {
        guard let currentPhotoID else {
            return
        }

        // Load listing and trigger copy
        Task { [weak self] in
            guard let ids = await self?.dependencies.infoReader.loadPhotoListingIDs(from: [currentPhotoID]) else {
                return
            }
            await MainActor.run { [self] in
                self?.copySharedPhoto(listings: ids)
            }
        }
    }

    private func copySharedPhoto(listings: Set<PhotoListingId>) {
        guard let copyToStreamController = dependencies.copyToStreamController else {
            return
        }
        let primaryIds = Set(listings.map(\.primary))
        let parameters = CopyPhotoParameters.ids(primaryIds: primaryIds)
        copyToStreamController.execute(parameters: parameters)
    }
}

// MARK: - Actions setup
extension PhotosPreviewActionViewModel {
    private func subscribeToUpdate() {
        dependencies.metadataController.readyIDs
            .sink { [weak self] readyIDs in
                guard
                    let self,
                    let currentPhotoID,
                    readyIDs.contains(currentPhotoID)
                else { return }
                self.isPhotoMetadataLoaded = true
                self.updateActions()
            }
            .store(in: &cancellables)

        dependencies.favoritingController.result
            .sink { [weak self] result in
                self?.handleFavoritingUpdate(result)
            }
            .store(in: &cancellables)

        dependencies.copyToStreamController?.isCopying
            .sink { [weak self] isCopying in
                self?.isCopying = isCopying
            }
            .store(in: &cancellables)
    }

    private func loadMetadata() {
        guard let currentPhotoID else { return }
        isPhotoMetadataLoaded = false
        dependencies.metadataController.loadImmediatelly([currentPhotoID])
    }

    private func setupSource() {
        guard let albumID else {
            source = .photoStream
            return
        }
        Task {
            guard let role = await dependencies.infoReader.getAlbumRole(id: albumID) else { return }
            await MainActor.run {
                self.source = .album(role)
                if self.isPhotoMetadataLoaded {
                    self.updateActions()
                }
            }
        }
    }

    private func updateActions() {
        if case .undetermined = source { return }
        Task {
            var isFavorited: Bool = false
            var canSaveSharedPhoto = false
            if let currentPhotoID {
                isFavorited = await dependencies.infoReader.isAllFavoritedPhotos(ids: [currentPhotoID])
                canSaveSharedPhoto = await dependencies.infoReader.isCopyToStreamAvailable(id: currentPhotoID)
            }
            await MainActor.run { [isFavorited, canSaveSharedPhoto] in
                let factory = PreviewToolBarItemFactory(
                    streamConfiguration: dependencies.streamConfiguration,
                    featuresController: dependencies.featureFlagsController
                )
                self.isLoading = false
                self.actions = factory.makeItems(for: source, isFavorited: isFavorited, hasSaveSharedPhoto: canSaveSharedPhoto)
            }
        }
    }
}

// MARK: - Action handling
extension PhotosPreviewActionViewModel {
    func handle(action: PhotosAction) {
        Log.info("[PreviewAction] Did select: \(action)", domain: .userAction)
        guard let currentPhotoID else { return }
        switch action {
        case .share, .newShare:
            share()
        case .toggleFavorite, .favorite, .unFavorite:
            dependencies.favoritingController.toggle(ids: [currentPhotoID])
        case .createAlbum:
            createAlbum()
        case .shareNative:
            dependencies.nativeSharePhotoController.share(id: currentPhotoID)
        case .availableOffline:
            dependencies.offlineAvailableController.toggle(ids: [currentPhotoID])
        case .info:
            openPhotoInfo()
        case .setAsAlbumCover:
            setAsAlbumCover()
        case .trash:
            trash(id: currentPhotoID)
        case .save:
            copySharedPhoto()
        case .more, .shareMultiple:
            break
        }
    }

    private func setAsAlbumCover() {
        guard
            let currentPhotoID,
            let albumID,
            let interactor = dependencies.updateAlbumInteractor
        else { return }
        Task {
            try await interactor.execute(
                parameters: .init(
                    albumID: albumID,
                    coverLinkID: currentPhotoID.id,
                    newAlbumName: nil,
                    originalHash: nil
                )
            )
        }
    }

    private func share() {
        guard let currentPhotoID else { return }
        switch source {
        case .undetermined:
            break
        case .photoStream:
            if hasAlbumsSharing() {
                Task {
                    let ids = await dependencies.infoReader.loadPhotoListingIDs(from: [currentPhotoID])
                    let controller = LocalPhotosSelectionController()
                    controller.start(selectedID: ids)
                    await MainActor.run {
                        dependencies.coordinator.openShareToSheet(selectionController: controller)
                    }
                }
            } else {
                dependencies.coordinator.openSharingConfiguration(for: currentPhotoID, type: .common)
            }
        case .album:
            dependencies.coordinator.openSharingConfiguration(for: currentPhotoID, type: .album)
        }
    }

    private func createAlbum() {
        guard let currentPhotoID else { return }
        Task {
            let ids = await dependencies.infoReader.loadPhotoListingIDs(from: [currentPhotoID])
            let controller = LocalPhotosSelectionController()
            controller.start(selectedID: ids)
            await MainActor.run {
                dependencies.coordinator.presentGroupToAlbumActionSheet(selectionController: controller)
            }
        }
    }

    private func openPhotoInfo() {
        guard let currentPhotoID else { return }
        dependencies.coordinator.openPhotoInfo(id: currentPhotoID)
    }

    private func trash(id: PhotoId) {
        switch source {
        case .undetermined:
            break
        case .photoStream:
            dialogModel = dependencies.trashDialogFactory.dialogForPhotoGalleryWith(ids: [id])
            currentAction = .trash
        case .album(let role):
            guard role == .admin || role == .editor else {
                return
            }

            var model: DialogSheetModel
            if role == .admin {
                model = dependencies.trashDialogFactory.removeFromAlbumAsAdmin(ids: [id])
            }
            // editor
            else {
                model = dependencies.trashDialogFactory.removeFromAlbumAsEditor(ids: [id])
            }

            dialogModel = model
            currentAction = .trash
        }
    }

    private func hasAlbumsSharing() -> Bool {
        return dependencies.featureFlagsController.hasAlbumsSharing && !dependencies.streamConfiguration.isLegacyShare
    }
}

extension PhotosPreviewActionViewModel {
    private func handleFavoritingUpdate(_ result: FavoritingResult) {
        switch result {
        case let .failure(error):
            let messageError = PlainMessageError(error.localizedDescription)
            dependencies.userMessageHandler.handleError(messageError)
        case let .success(output):
            switch output {
            case let .markedFavorite(favoritingOutput):
                var messages = [String]()
                if favoritingOutput.copiedToStream > 0 {
                    messages.append(Localization.favoriting_result_copied(count: favoritingOutput.copiedToStream))
                }
                if favoritingOutput.skipped > 0 {
                    messages.append(Localization.favoriting_result_skipped(count: favoritingOutput.skipped))
                }
                if favoritingOutput.streamPhotos > 0 {
                    messages.append(Localization.favoriting_result_marked(count: favoritingOutput.streamPhotos))
                }
                if !messages.isEmpty {
                    let message = messages.joinedNonEmpty(separator: "\n")
                    dependencies.userMessageHandler.handleSuccess(message)
                }
            case let .unmarkedFavorite(count):
                dependencies.userMessageHandler.handleSuccess(Localization.favoriting_result_unmarked(count: count))
            }
            updateActions()
        }
    }
}

extension PhotosPreviewActionViewModel {
    struct Dependencies {
        let coordinator: PhotosPreviewActionCoordinatorProtocol
        let favoritingController: FavoritingControllerProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let infoReader: PhotosPreviewItemInfoReaderProtocol
        let metadataController: MetadataControllerProtocol
        let nativeSharePhotoController: NativeSharePhotoControllerProtocol
        let offlineAvailableController: OfflineAvailableController
        let streamConfiguration: PhotoStreamConfiguration
        let trashDialogFactory: TrashDialogFactoryProtocol
        let userMessageHandler: UserMessageHandlerProtocol
        let copyToStreamController: CopyPhotosToStreamControllerProtocol?

        // Album only dependencies
        let updateAlbumInteractor: UpdateAlbumInteractorProtocol?
    }
}
