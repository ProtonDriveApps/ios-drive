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
import Foundation
import PDUIComponents
import PDLocalization

enum PhotosAction: Identifiable {
    var id: String {
        "\(self)"
    }

    case trash
    case share
    case newShare
    case shareNative
    case availableOffline
    case info
}

protocol PhotosActionViewModelProtocol: ObservableObject {
    var isVisible: Bool { get }
    var currentAction: PhotosAction? { get set }
    var actions: [PhotosAction] { get }
    func handle(action: PhotosAction)
    func makeDialogModel() -> DialogSheetModel
}

final class PhotosActionViewModel: PhotosActionViewModelProtocol {
    private let trashController: PhotosTrashController
    private let coordinator: PhotosActionCoordinator
    private let selectionController: PhotosSelectionController
    private let fileContentController: FileContentController
    private let offlineAvailableController: OfflineAvailableController
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private var cancellables = Set<AnyCancellable>()

    @Published var isVisible = false
    @Published var currentAction: PhotosAction?
    @Published var actions = [PhotosAction]()

    init(trashController: PhotosTrashController, coordinator: PhotosActionCoordinator, selectionController: PhotosSelectionController, fileContentController: FileContentController, offlineAvailableController: OfflineAvailableController, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.trashController = trashController
        self.coordinator = coordinator
        self.selectionController = selectionController
        self.fileContentController = fileContentController
        self.offlineAvailableController = offlineAvailableController
        self.featureFlagsController = featureFlagsController
        subscribeToUpdates()
        handleUpdate()
    }

    private func subscribeToUpdates() {
        selectionController.updatePublisher
            .sink { [weak self] in
                self?.handleUpdate()
            }
            .store(in: &cancellables)

        fileContentController.content
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] content in
                self?.handleFileUpdate(content)
            })
            .store(in: &cancellables)
    }

    private func handleUpdate() {
        let isSelecting = selectionController.isSelecting()
        if !isSelecting {
            fileContentController.clear()
        }
        coordinator.updateTabBar(isHidden: isSelecting)
        isVisible = isSelecting && !selectionController.getIds().isEmpty
        actions = makeActions()
    }

    private func makeActions() -> [PhotosAction] {
        let ids = selectionController.getIds()
        if ids.isEmpty {
            return []
        } else if ids.count == 1 && featureFlagsController.hasSharing {
            return [.newShare, .shareNative, .availableOffline, .info, .trash]
        } else if ids.count == 1 {
            return [.share, .shareNative, .availableOffline, .info, .trash]
        } else {
            return [.availableOffline, .trash]
        }
    }

    func handle(action: PhotosAction) {
        switch action {
        case .trash:
            currentAction = .trash
        case .share, .newShare:
            share()
        case .shareNative:
            shareNative()
        case .availableOffline:
            let ids = selectionController.getIds()
            offlineAvailableController.toggle(ids: ids)
        case .info:
            openPhotoInfo()
        }
    }

    private func share() {
        if let id = getSingleId() {
            coordinator.openShare(id: id)
        }
    }

    private func getSingleId() -> PhotoId? {
        let ids = selectionController.getIds()
        return ids.count == 1 ? ids.first : nil
    }

    func makeDialogModel() -> DialogSheetModel {
        switch currentAction {
        case .trash:
            let button = DialogButton(title: makeTrashDialogButtonTitle(), role: .destructive) { [weak self] in
                let ids = self?.selectionController.getIds() ?? []
                self?.trashController.trash(ids: ids)
                self?.selectionController.cancel()
            }
            return DialogSheetModel(title: makeTrashDialogTitle(), buttons: [button])
        default:
            return .placeholder
        }
    }

    private func makeTrashDialogTitle() -> String {
        let count = selectionController.getIds().count
        return Localization.action_trash_items_alert_message(num: count)
    }

    private func makeTrashDialogButtonTitle() -> String {
        let count = selectionController.getIds().count
        return Localization.photo_action_remove_item(num: count)
    }
    
    private func openPhotoInfo() {
        guard let id = getSingleId() else { return }
        coordinator.openPhotoDetail(id: id)
    }
}

// MARK: - Native share
extension PhotosActionViewModel {
    private func shareNative() {
        if let id = getSingleId() {
            fileContentController.execute(with: id)
        }
    }

    private func handleFileUpdate(_ content: FileContent?) {
        guard let content else { return }

        if content.couldBeLivePhoto, let videoURL = content.childrenURLs.first {
            coordinator.openNativeShareForLivePhoto(imageURL: content.url, videoURL: videoURL) { [weak self] in
                self?.fileContentController.clear()
            }
        } else if content.couldBeBurst {
            coordinator.openNativeShareForBurstPhoto(urls: [content.url] + content.childrenURLs) { [weak self] in
                self?.fileContentController.clear()
            }
        } else {
            share(url: content.url)
        }
    }

    private func share(url: URL) {
        coordinator.openNativeShare(url: url) { [weak self] in
            self?.fileContentController.clear()
        }
    }
}
