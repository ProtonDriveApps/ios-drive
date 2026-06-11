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

final class PhotoGalleryActionViewModel: BasePhotosActionViewModel, PhotosActionViewModelProtocol {
    let streamConfiguration: PhotoStreamConfiguration

    init(
        coordinator: any PhotosActionCoordinator,
        selectionController: any PhotosSelectionController,
        fileContentController: any FileContentController,
        offlineAvailableController: any OfflineAvailableController,
        featureFlagsController: any FeatureFlagsControllerProtocol,
        metadataController: any MetadataControllerProtocol,
        favoritingController: any FavoritingControllerProtocol,
        trashDialogFactory: any TrashDialogFactoryProtocol,
        userMessageHandler: any UserMessageHandlerProtocol,
        streamConfiguration: PhotoStreamConfiguration,
        configuration: PhotosRootConfiguration
    ) {
        self.streamConfiguration = streamConfiguration

        super.init(
            coordinator: coordinator,
            selectionController: selectionController,
            fileContentController: fileContentController,
            offlineAvailableController: offlineAvailableController,
            featureFlagsController: featureFlagsController,
            metadataController: metadataController,
            favoritingController: favoritingController,
            trashDialogFactory: trashDialogFactory,
            userMessageHandler: userMessageHandler,
            configuration: configuration
        )
    }

    override var type: PhotosActionParentType { .photoGallery }

    override func makeActions() -> PhotosActions {
        let unsortedActions = makeUnsortedActions()
        let sortedActions = sortActions(unsortedActions)
        return sortedActions
    }

    private func makeUnsortedActions() -> Set<PhotosAction> {
        let ids = selectionController.getPrimaryIds()
        guard !ids.isEmpty else { return [] }

        var actions = allSelectionActions(for: ids)
        actions.formUnion(singleSelectionActions(for: ids))
        actions.formUnion(multipleSelectionActions(for: ids))

        return actions
    }

    func allSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        return [
            .availableOffline,
            .trash,
            .toggleFavorite,
            .createAlbum
        ]
    }

    func singleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard ids.count == 1 else { return [] }

        var actions: Set<PhotosAction> = [.shareNative, .info]

        if featureFlagsController.hasSharing {
            actions.insert(.newShare)
        } else {
            actions.insert(.share)
        }

        return actions
    }

    func multipleSelectionActions(for ids: Set<AnyVolumeIdentifier>) -> Set<PhotosAction> {
        guard ids.count > 1 else { return [] }

        var actions: Set<PhotosAction> = []

        if hasSharing() {
            actions.insert(.shareMultiple)
        }

        return Set(actions)
    }
}

extension PhotoGalleryActionViewModel {
    func handle(action: PhotosAction) {
        Log.info("[GalleryAction] Did select: \(action)", domain: .userAction)
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
        case .createAlbum:
            createAlbum()
        case .shareMultiple:
            shareMultiple()
        case .setAsAlbumCover:
            break // only AlbumActionViewModel implements
        case .more:
            break // doesn't really have an action
        case .favorite:
            break
        case .unFavorite:
            break
        case .save, .removeFromAlbum:
            break // not available in gallery context
        }
    }

    func trash() {
        self.confirmationRequiringActionModel = trashDialogFactory.dialogForPhotoGallery()
    }

    func share() {
        guard !selectionController.getPrimaryIds().isEmpty else {
            return
        }

        if hasSharing() {
            coordinator.openShareToSheet(selectionController: selectionController)
        } else if let id = getSingleId() {
            coordinator.openShare(id: id)
        }
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

    func createAlbum() {
        coordinator.presentGroupToAlbumActionSheet(selectionController: selectionController)
    }

    func shareMultiple() {
        coordinator.openShareToSheet(selectionController: selectionController)
    }

    func share(url: URL) {
        coordinator.openNativeShare(url: url) {
            self.fileContentController.clear()
        }
    }

    func makeDialogModel() -> DialogSheetModel {
        return .placeholder
    }

    private func hasSharing() -> Bool {
        return featureFlagsController.hasSharing
    }
}
