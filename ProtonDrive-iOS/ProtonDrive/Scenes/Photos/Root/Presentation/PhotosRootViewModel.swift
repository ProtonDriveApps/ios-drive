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
    case loading
    case onboarding
    case permissions
    case gallery
    case disconnection
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
    func refreshIfNeeded()
}

final class PhotosRootViewModel: PhotosRootViewModelProtocol {
    private let coordinator: PhotosRootCoordinator
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let galleryController: PhotosGalleryController
    private let selectionController: PhotosSelectionController
    private var cancellables = Set<AnyCancellable>()
    private let photosPagingLoadController: PhotosPagingLoadController

    @Published var state: PhotosRootState = .loading
    @Published var navigation: PhotosRootNavigation = .default

    init(
        coordinator: PhotosRootCoordinator,
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        galleryController: PhotosGalleryController,
        selectionController: PhotosSelectionController,
        photosPagingLoadController: PhotosPagingLoadController
    ) {
        self.coordinator = coordinator
        self.settingsController = settingsController
        self.authorizationController = authorizationController
        self.galleryController = galleryController
        self.selectionController = selectionController
        self.photosPagingLoadController = photosPagingLoadController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        galleryController.sections
            .sink { [weak self] sections in
                let hasPhotos = !sections.isEmpty
                if hasPhotos {
                    self?.state = .gallery
                }
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            authorizationController.permissions,
            settingsController.isEnabled,
            galleryController.sections,
            photosPagingLoadController.loadStatus
        )
        .compactMap { [weak self] permissions, isBackupEnabled, sections, photoLoadStatus in
            self?.map(permissions: permissions, isBackupEnabled: isBackupEnabled, hasPhotos: !sections.isEmpty, photoLoadStatus: photoLoadStatus)
        }
        .removeDuplicates()
        .assign(to: &$state)

        Publishers.CombineLatest(selectionController.updatePublisher, galleryController.sections.removeDuplicates())
            .sink { [weak self] _ in
                self?.handleSelectionUpdate()
            }
            .store(in: &cancellables)
    }

    private func map(
        permissions: PhotoLibraryPermissions,
        isBackupEnabled: Bool,
        hasPhotos: Bool,
        photoLoadStatus: RemotePhotoLoadStatus
    ) -> PhotosRootState {
        if case .undetermined = photoLoadStatus, !hasPhotos, state == .loading {
            return .loading
        }
        
        if case .disconnected = photoLoadStatus, !hasPhotos {
            return .disconnection
        } else if hasPhotos || (permissions == .full && isBackupEnabled) || photoLoadStatus.hasBackedUpPhoto {
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
    
    func refreshIfNeeded() {
        guard state == .disconnection else { return }
        photosPagingLoadController.loadNext()
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
