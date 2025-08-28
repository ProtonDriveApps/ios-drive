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
import PDLocalization

enum GalleryRootState: Equatable {
    case loading
    case onboarding
    case permissions
    case gallery
    case disconnection
}

protocol GalleryRootViewModelProtocol: ObservableObject {
    var state: GalleryRootState { get }
    var isVisible: Bool { get }
    var visiblePublisher: AnyPublisher<Bool, Never> { get }

    func refreshIfNeeded()
    func updateVisibleStatus(isVisible: Bool)
}

final class GalleryRootViewModel: GalleryRootViewModelProtocol {
    private let configuration: PhotosRootConfiguration
    private let settingsController: PhotoBackupSettingsController
    private let authorizationController: PhotoLibraryAuthorizationController
    private let ownPhotosController: OwnPhotosControllerProtocol
    private let fetchingController: PhotosListFetchingControllerProtocol
    private let fetchingStatusController: PhotosListFetchingStatusControllerProtocol
    private let photoUpsellFlowController: PhotoUpsellFlowController?
    private let screenLockController: ScreenLockController
    private var cancellables = Set<AnyCancellable>()
    /// Is photos root view visible on the screen
    var isVisible: Bool { visibleSubject.value }
    private var visibleSubject = CurrentValueSubject<Bool, Never>(true)

    @Published var state: GalleryRootState = .loading
    var visiblePublisher: AnyPublisher<Bool, Never> {
        visibleSubject.eraseToAnyPublisher()
    }

    init(
        configuration: PhotosRootConfiguration,
        settingsController: PhotoBackupSettingsController,
        authorizationController: PhotoLibraryAuthorizationController,
        ownPhotosController: OwnPhotosControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        fetchingStatusController: PhotosListFetchingStatusControllerProtocol,
        photoUpsellFlowController: PhotoUpsellFlowController?,
        screenLockController: ScreenLockController
    ) {
        self.configuration = configuration
        self.settingsController = settingsController
        self.authorizationController = authorizationController
        self.ownPhotosController = ownPhotosController
        self.fetchingController = fetchingController
        self.fetchingStatusController = fetchingStatusController
        self.photoUpsellFlowController = photoUpsellFlowController
        self.screenLockController = screenLockController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest4(
            authorizationController.permissions,
            settingsController.isEnabled,
            ownPhotosController.hasPhotos,
            fetchingStatusController.status
        )
        .compactMap { [weak self] permissions, isBackupEnabled, hasPhotos, status in
            self?.map(permissions: permissions, isBackupEnabled: isBackupEnabled, hasPhotos: hasPhotos, status: status)
        }
        .removeDuplicates()
        .assign(to: &$state)
    }

    private func map(
        permissions: PhotoLibraryPermissions,
        isBackupEnabled: Bool,
        hasPhotos: Bool,
        status: PhotosListFetchingStatus
    ) -> GalleryRootState {
        if hasPhotos {
            return .gallery
        }

        if case .undetermined = status, state == .loading {
            return .loading
        } else if case .disconnected = status {
            return .disconnection
        } else if case .failure = status {
            return .disconnection
        } else if (permissions == .full && isBackupEnabled) || status.hasBackedUpPhoto {
            return .gallery
        } else if permissions == .restricted {
            return .permissions
        } else {
            return configuration.isPickingPhotos ? .gallery : .onboarding
        }
    }

    func refreshIfNeeded() {
        fetchingController.loadIfEmpty()
    }

    func updateVisibleStatus(isVisible: Bool) {
        visibleSubject.send(isVisible)
        photoUpsellFlowController?.updatePhotoTabVisible(isVisible: isVisible)
        screenLockController.setVisible(isVisible)
    }
}
