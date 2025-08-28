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

import PDUIComponents
import PDLocalization
import PDCore
import Foundation
import PDCoreIOS

final class AlbumActionViewModel: BasePhotosActionViewModel, PhotosActionViewModelProtocol {

    private let updateAlbumInteractor: UpdateAlbumInteractorProtocol
    private let albumRepository: AlbumRepositoryProtocol
    private let copyToStreamController: CopyPhotosToStreamControllerProtocol

    private var albumRole: Role?

    override var type: PhotosActionParentType {
        .album
    }

    init(
        coordinator: PhotosActionCoordinator,
        selectionController: PhotosSelectionController,
        fileContentController: FileContentController,
        offlineAvailableController: OfflineAvailableController,
        featureFlagsController: FeatureFlagsControllerProtocol,
        metadataController: MetadataControllerProtocol,
        favoritingController: FavoritingControllerProtocol,
        trashDialogFactory: TrashDialogFactoryProtocol,
        userMessageHandler: UserMessageHandlerProtocol,
        updateAlbumInteractor: UpdateAlbumInteractorProtocol,
        albumRepository: AlbumRepositoryProtocol,
        copyToStreamController: CopyPhotosToStreamControllerProtocol
    ) {
        self.updateAlbumInteractor = updateAlbumInteractor
        self.albumRepository = albumRepository
        self.copyToStreamController = copyToStreamController
        super.init(
            coordinator: coordinator,
            selectionController: selectionController,
            fileContentController: fileContentController,
            offlineAvailableController: offlineAvailableController,
            featureFlagsController: featureFlagsController,
            metadataController: metadataController,
            favoritingController: favoritingController,
            trashDialogFactory: trashDialogFactory,
            userMessageHandler: userMessageHandler
        )
        subscribeToAlbumUpdates()
    }

    private func subscribeToAlbumUpdates() {
        albumRepository.updatePublisher
            .sink { [weak self] album in
                guard let self, let album else { return }
                self.albumRole = album.role
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    override func makeActions() -> PhotosActions {
        let unsortedActions = makeUnsortedActions()
        let sortedActions = sortActions(unsortedActions)
        return sortedActions
    }

    private func makeUnsortedActions() -> Set<PhotosAction> {
        let ids = selectionController.getPrimaryIds()
        guard !ids.isEmpty else { return [] }

        var actions = makeAdminSingleSelectionActions(for: ids)
        actions.formUnion(makeAdminMultipleSelectionActions(for: ids))
        actions.formUnion(makeEditorSingleSelectionActions(for: ids))
        actions.formUnion(makeEditorMultipleSelectionActions(for: ids))
        actions.formUnion(makeViewerSingleSelectionActions(for: ids))
        actions.formUnion(makeViewerMultipleSelectionActions(for: ids))

        return actions
    }

    private func makeAdminSingleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard albumRole == .admin,
              ids.count == 1 else {
            return []
        }
        var actions = Set<PhotosAction>()
        actions.insert(.trash)
        actions.insert(.availableOffline)

        if featureFlagsController.hasAlbumsActions {
            actions.insert(.toggleFavorite)
            actions.insert(.setAsAlbumCover)
        }
        
        actions.insert(.shareNative)
        actions.insert(.info)

        if featureFlagsController.hasSharing {
            actions.insert(.newShare)
        } else {
            actions.insert(.share)
        }

        return actions
    }

    private func makeAdminMultipleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard albumRole == .admin,
              ids.count > 1 else {
            return []
        }

        var actions = Set<PhotosAction>()
        actions.insert(.trash)
        actions.insert(.availableOffline)

        if featureFlagsController.hasAlbumsActions {
            actions.insert(.toggleFavorite)
        }

        return actions
    }

    private func makeEditorSingleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard albumRole == .editor,
              ids.count == 1 else {
            return []
        }
        var actions = Set<PhotosAction>()
        actions.insert(.save)
        actions.insert(.trash)
        actions.insert(.availableOffline)

        if featureFlagsController.hasAlbumsActions {
            actions.insert(.toggleFavorite)
        }

        actions.insert(.shareNative)
        actions.insert(.info)

        return actions
    }

    private func makeEditorMultipleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard albumRole == .editor,
              ids.count > 1 else {
            return []
        }

        var actions = Set<PhotosAction>()
        actions.insert(.save)
        actions.insert(.trash)
        actions.insert(.availableOffline)

        if featureFlagsController.hasAlbumsActions {
            actions.insert(.toggleFavorite)
        }

        return actions
    }

    private func makeViewerSingleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard albumRole == .viewer,
              ids.count == 1 else {
            return []
        }
        var actions = Set<PhotosAction>()
        actions.insert(.save)
        actions.insert(.availableOffline)

        if featureFlagsController.hasAlbumsActions {
            actions.insert(.toggleFavorite)
        }

        actions.insert(.shareNative)
        actions.insert(.info)

        return actions
    }

    private func makeViewerMultipleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard albumRole == .viewer,
              ids.count > 1 else {
            return []
        }

        var actions = Set<PhotosAction>()
        actions.insert(.save)
        actions.insert(.availableOffline)

        // ❓ do viewers can toggleFavorite?
        if featureFlagsController.hasAlbumsActions {
            actions.insert(.toggleFavorite)
        }

        return actions
    }

    func handle(action: PhotosAction) {
        Log.info("[AlbumAction] Did select: \(action)", domain: .userAction)
        switch action {
        case .trash:
            trash()
        case .share, .newShare:
            share()
        case .shareNative:
            shareNative()
        case .availableOffline:
            availableOffline()
        case .info:
            openPhotoInfo()
        case .toggleFavorite:
            favorite()
        case .setAsAlbumCover:
            setAsAlbumCover()
        case .createAlbum, .shareMultiple, .more:
            break // not available in album context
        case .favorite:
            break
        case .unFavorite:
            break
        case .save:
            copySelectedPhotosToStream()
        }
    }

    // MARK: - Action Handlers
    func trash() {
        let ids = selectionController.getPrimaryIds()

        if albumRole == .admin {
            trashAsAdmin(ids: ids)

        } else if albumRole == .editor {
            trashAsEditor(ids: ids)
        } else {
            Log.error("Tried to trash photos as viewer, of before the role was determined", error: nil, domain: .albums)
        }
    }

    private func trashAsAdmin(ids: Set<PhotoId>) {
        let model = trashDialogFactory.removeFromAlbumAsAdmin(ids: ids)
        confirmationRequiringActionModel = model
    }

    private func trashAsEditor(ids: Set<PhotoId>) {
        let model = trashDialogFactory.removeFromAlbumAsEditor(ids: ids)
        confirmationRequiringActionModel = model
    }

    func share() {
        guard let id = getSingleId() else { return }
        coordinator.openShare(id: id)
    }

    func shareNative() {
        guard let id = getSingleId() else { return }
        fileContentController.execute(with: id)
    }

    func availableOffline() {
        let ids = selectionController.getAllIds()
        offlineAvailableController.toggle(ids: ids)
    }

    func openPhotoInfo() {
        guard let id = getSingleId() else { return }
        coordinator.openPhotoDetail(id: id)
    }

    func favorite() {
        let ids = selectionController.getPrimaryIds()
        favoritingController.toggle(ids: ids)
    }

    func setAsAlbumCover() {
        guard
            let id = selectionController.getPrimaryIds().first else {
            assert(false)
            return
        }

        let albumID = albumRepository.albumID

        selectionController.cancel()
        Task {
            try await updateAlbumInteractor.execute(
                parameters: .init(
                    albumID: albumID,
                    coverLinkID: id.id,
                    newAlbumName: nil,
                    originalHash: nil
                )
            )
        }
    }

    func makeDialogModel() -> DialogSheetModel {
        return .placeholder
    }

    private func copySelectedPhotosToStream() {
        let ids = selectionController.getPrimaryIds()
        let parameters = CopyPhotoParameters.ids(primaryIds: ids)
        copyToStreamController.execute(parameters: parameters)
    }
}
