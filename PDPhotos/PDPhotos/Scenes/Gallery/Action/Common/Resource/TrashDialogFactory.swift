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
import PDLocalization
import PDUIComponents
import PDCore

protocol TrashDialogFactoryProtocol {
    func dialogForPhotoGallery() -> DialogSheetModel
    func dialogForPhotoGalleryWith(ids: Set<PhotoId>) -> DialogSheetModel
    func dialogForAlbum() async -> DialogSheetModel
    func dialogForAlbumWith(ids: Set<PhotoId>) async -> DialogSheetModel

    func removeFromAlbumAsAdmin(ids: Set<PhotoId>) -> DialogSheetModel
    func removeFromAlbumAsEditor(ids: Set<PhotoId>) -> DialogSheetModel
}

final class TrashDialogFactory: TrashDialogFactoryProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func dialogForPhotoGallery() -> DialogSheetModel {
        let ids = dependencies.selectionController.getPrimaryIds()
        return dialogForPhotoGalleryWith(ids: ids)
    }

    func dialogForPhotoGalleryWith(ids: Set<PhotoId>) -> DialogSheetModel {
        let count = ids.count
        let title = Localization.action_trash_items_alert_message(num: count)
        let buttonTitle = Localization.photo_action_remove_item(num: count)

        let button = DialogButton(title: buttonTitle, role: .destructive, action: { [weak self] in
            self?.removePhotosFromStreams(ids: ids)
        })
        return DialogSheetModel(title: title, buttons: [button])
    }

    func dialogForAlbum() async -> DialogSheetModel {
        let ids = dependencies.selectionController.getPrimaryIds()
        return await dialogForAlbumWith(ids: ids)
    }

    func removeFromAlbumAsAdmin(ids: Set<PhotoId>) -> DialogSheetModel {
        let title = Localization.album_photo_remove_warning_admin

        let removeButton = DialogButton(title: Localization.album_photo_remove_warning_admin_confirmation, role: .destructive) { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                try await self?.removePhotosFromAlbum(ids: ids)
            }
            self.dependencies.selectionController.cancel()
        }

        return DialogSheetModel(title: title, buttons: [removeButton])
    }

    func removeFromAlbumAsEditor(ids: Set<PhotoId>) -> DialogSheetModel {
        let title = Localization.album_photo_remove_warning_editor(num: ids.count)

        let removeButton = DialogButton(title: Localization.album_photo_remove_warning_editor_continue, role: .destructive) { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                try await self?.removePhotosFromAlbum(ids: ids)
            }
            self.dependencies.selectionController.cancel()
        }

        return DialogSheetModel(title: title, buttons: [removeButton])
    }

    func dialogForAlbumWith(ids: Set<PhotoId>) async -> DialogSheetModel {
        let title = Localization.album_photo_remove_warning(num: ids.count).split(separator: ",").first ?? ""
        let removeFromAlbumButton = DialogButton(
            title: Localization.action_remove_photos,
            role: .default
        ) { [weak self] in
            Task { [weak self] in
                try await self?.removePhotosFromAlbum(ids: ids)
            }
            self?.dependencies.selectionController.cancel()
        }
        let deleteButton = DialogButton(
            title: Localization.edit_section_remove,
            role: .destructive
        ) { [weak self] in
            self?.removePhotosFromStreams(ids: ids)
        }

        var buttons: [DialogButton] = [removeFromAlbumButton]
        let hasAlbumChildren = await hasAlbumChildren(in: ids)
        if !hasAlbumChildren {
            buttons.append(deleteButton)
        }
        return DialogSheetModel(title: String(title), buttons: buttons)
    }

    private func hasAlbumChildren(in photoIDs: Set<PhotoId>) async -> Bool {
        let context = dependencies.context
        return await context.perform {
            let photos = CoreDataPhoto.fetch(identifiers: photoIDs, in: context)
            for photo in photos {
                let photoInStream = photo.photoListings.first(where: { $0.albumID == nil })
                if photoInStream == nil {
                    return true
                }
            }
            return false
        }
    }

    private func removePhotosFromAlbum(ids: Set<PhotoId>) async throws {
        do {
            try await dependencies.removePhotosController?.execute(ids: ids)
            await MainActor.run { [weak self] in
                guard let volumeID = ids.first?.volumeID else { return }
                self?.dependencies.eventsSystemManager.forcePolling(volumeIDs: [volumeID])
            }
        } catch {
            Log.error("Remove photos from album failed", error: error, domain: .albums)
            dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
            throw error
        }
    }

    private func removePhotosFromStreams(ids: Set<PhotoId>) {
        dependencies.trashController.trash(ids: ids)
        dependencies.selectionController.cancel()
    }
}

extension TrashDialogFactory {
    struct Dependencies {
        let context: NSManagedObjectContext
        let trashController: PhotosTrashController
        let selectionController: PhotosSelectionController
        let removePhotosController: RemovePhotosControllerProtocol?
        let eventsSystemManager: EventsSystemManager
        let userMessageHandler: UserMessageHandlerProtocol
    }
}
