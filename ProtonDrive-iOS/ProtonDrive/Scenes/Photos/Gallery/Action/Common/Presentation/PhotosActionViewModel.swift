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

enum PhotosAction: Identifiable {
    var id: String {
        "\(self)"
    }

    case trash
    case share
    case shareNative
    case availableOffline
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
    private var cancellables = Set<AnyCancellable>()

    @Published var isVisible = false
    @Published var currentAction: PhotosAction?
    @Published var actions = [PhotosAction]()

    init(trashController: PhotosTrashController, coordinator: PhotosActionCoordinator, selectionController: PhotosSelectionController, fileContentController: FileContentController, offlineAvailableController: OfflineAvailableController) {
        self.trashController = trashController
        self.coordinator = coordinator
        self.selectionController = selectionController
        self.fileContentController = fileContentController
        self.offlineAvailableController = offlineAvailableController
        subscribeToUpdates()
        handleUpdate()
    }

    private func subscribeToUpdates() {
        selectionController.updatePublisher
            .sink { [weak self] in
                self?.handleUpdate()
            }
            .store(in: &cancellables)

        fileContentController.url
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] url in
                self?.handleFileUpdate(url)
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

    private func handleFileUpdate(_ url: URL?) {
        guard let url = url else {
            return
        }
        coordinator.openNativeShare(url: url) { [weak self] in
            self?.fileContentController.clear()
        }
    }

    private func makeActions() -> [PhotosAction] {
        let ids = selectionController.getIds()
        if ids.isEmpty {
            return []
        } else if ids.count == 1 {
            return [.share, .shareNative, .availableOffline, .trash]
        } else {
            return [.availableOffline, .trash]
        }
    }

    func handle(action: PhotosAction) {
        switch action {
        case .trash:
            currentAction = .trash
        case .share:
            share()
        case .shareNative:
            shareNative()
        case .availableOffline:
            let ids = selectionController.getIds()
            offlineAvailableController.toggle(ids: ids)
        }
    }

    private func share() {
        if let id = getSingleId() {
            coordinator.openShare(id: id)
        }
    }

    private func shareNative() {
        if let id = getSingleId() {
            fileContentController.execute(with: id)
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
        if count == 1 {
            return "Are you sure you want to move this item to Trash?"
        } else {
            return "Are you sure you want to move \(count) items to Trash?"
        }
    }

    private func makeTrashDialogButtonTitle() -> String {
        let count = selectionController.getIds().count
        if count == 1 {
            return "Remove item"
        } else {
            return "Remove \(count) items"
        }
    }
}
