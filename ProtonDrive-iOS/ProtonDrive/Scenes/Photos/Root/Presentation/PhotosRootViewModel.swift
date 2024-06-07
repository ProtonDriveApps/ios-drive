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

enum PhotosRootState {
    case onboarding
    case permissions
    case gallery
}

struct PhotosRootNavigation {
    let title: String
    let leftItem: Item
    let rightItem: Item?

    static let `default` = PhotosRootNavigation(title: "Photos", leftItem: .menu, rightItem: nil)

    enum Item: Equatable {
        case menu
        case selection(String)
        case cancel(String)
    }
}

protocol PhotosRootViewModelProtocol: ObservableObject {
    var state: PhotosRootState { get }
    var navigation: PhotosRootNavigation { get }
    func handle(item: PhotosRootNavigation.Item)
    func close()
}

final class PhotosRootViewModel: PhotosRootViewModelProtocol {
    private let coordinator: PhotosRootCoordinator
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let galleryController: PhotosGalleryController
    private let selectionController: PhotosSelectionController
    private var cancellables = Set<AnyCancellable>()

    @Published var state: PhotosRootState = .onboarding
    @Published var navigation: PhotosRootNavigation = .default

    init(coordinator: PhotosRootCoordinator, settingsController: PhotoBackupSettingsController, authorizationController: PhotoLibraryAuthorizationController, galleryController: PhotosGalleryController, selectionController: PhotosSelectionController) {
        self.coordinator = coordinator
        self.settingsController = settingsController
        self.authorizationController = authorizationController
        self.galleryController = galleryController
        self.selectionController = selectionController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest3(
            authorizationController.permissions,
            settingsController.isEnabled,
            galleryController.sections
        )
        .compactMap { [weak self] permissions, isBackupEnabled, sections in
            self?.map(permissions: permissions, isBackupEnabled: isBackupEnabled, hasPhotos: !sections.isEmpty)
        }
        .removeDuplicates()
        .assign(to: &$state)

        Publishers.CombineLatest(selectionController.updatePublisher, galleryController.sections.removeDuplicates())
            .sink { [weak self] _ in
                self?.handleSelectionUpdate()
            }
            .store(in: &cancellables)
    }

    private func map(permissions: PhotoLibraryPermissions, isBackupEnabled: Bool, hasPhotos: Bool) -> PhotosRootState {
        if hasPhotos || (permissions == .full && isBackupEnabled) {
            return .gallery
        } else if permissions == .restricted {
            return .permissions
        } else {
            return .onboarding
        }
    }

    func handle(item: PhotosRootNavigation.Item) {
        switch item {
        case .menu:
            coordinator.openMenu()
        case .cancel:
            selectionController.cancel()
        case .selection:
            if isFullSelection() {
                selectionController.deselectAll()
            } else {
                selectionController.select(ids: galleryController.getIds())
            }
        }
    }

    func close() {
        coordinator.close()
    }

    private func isFullSelection() -> Bool {
        let selectedIds = selectionController.getIds()
        let allIds = galleryController.getIds()
        return selectedIds.isSuperset(of: allIds)
    }

    private func handleSelectionUpdate() {
        if selectionController.isSelecting() {
            let selectedIds = selectionController.getIds()
            let selectedAllTitle = isFullSelection() ? "Deselect all" : "Select all"
            navigation = PhotosRootNavigation(
                title: "\(selectedIds.count) selected",
                leftItem: .selection(selectedAllTitle),
                rightItem: .cancel("Cancel")
            )
        } else {
            navigation = .default
        }
    }
}
