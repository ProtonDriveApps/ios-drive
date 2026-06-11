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
import Foundation
import PDLocalization
import PDCore
import PDCoreIOS

enum PhotosRootViewState: Equatable {
    case loading
    case finished(PhotoStreamConfiguration)
    case message(String)

    var isFinished: Bool {
        if case .finished = self {
            return true
        } else {
            return false
        }
    }
}

public struct PhotosRootConfiguration {
    let isPickingPhotos: Bool
    let selectionController: PhotosSelectionController?

    public init(isPickingPhotos: Bool = false, selectionController: PhotosSelectionController? = nil) {
        self.isPickingPhotos = isPickingPhotos
        self.selectionController = selectionController
    }
}

protocol PhotosRootViewModelProtocol: ObservableObject {
    var state: PhotosRootViewState { get }
    var galleryType: GalleryType { get }
    var navigation: PhotosRootNavigation? { get }
    var areAlbumsEnabled: Bool { get }

    func start()
    func onAppear(streamConfiguration: PhotoStreamConfiguration)
    func handle(galleryType: GalleryType)
    func handle(navigation: PhotosRootNavigation.Item)
    func close()
}

final class PhotosRootViewModel: PhotosRootViewModelProtocol {
    private let bootstrapController: PhotoVolumeBootstrapControllerProtocol
    private let configuration: PhotosRootConfiguration
    private let coordinator: PhotosRootCoordinator
    private var cancellables = Set<AnyCancellable>()
    let selectionController: PhotosSelectionController
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let userInfoController: UserInfoController
    private var streamConfiguration: PhotoStreamConfiguration?
    private let localSettings: LocalSettings
    private let tagsMigrationConstraintController: MigrationConstraintController

    @Published var state: PhotosRootViewState = .loading
    @Published var galleryType: GalleryType = .photos
    @Published var navigation: PhotosRootNavigation? = .default(
        isPaidUser: false,
        showTagMigrationSpinner: false
    )
    @Published var areAlbumsEnabled: Bool = false
    private var isPaidUser = false {
        didSet {
            updatePhotosNavigationBarItems()
        }
    }

    init(
        bootstrapController: PhotoVolumeBootstrapControllerProtocol,
        selectionController: PhotosSelectionController,
        configuration: PhotosRootConfiguration,
        coordinator: PhotosRootCoordinator,
        featureFlagsController: FeatureFlagsControllerProtocol,
        userInfoController: UserInfoController,
        localSettings: LocalSettings,
        tagsMigrationConstraintController: MigrationConstraintController
    ) {
        self.bootstrapController = bootstrapController
        self.selectionController = selectionController
        self.configuration = configuration
        self.coordinator = coordinator
        self.featureFlagsController = featureFlagsController
        self.userInfoController = userInfoController
        self.localSettings = localSettings
        self.tagsMigrationConstraintController = tagsMigrationConstraintController
        if configuration.isPickingPhotos {
            navigation = .picker
        } else {
            updatePhotosNavigationBarItems()
        }
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        bootstrapController.state
            .compactMap { [weak self] state in
                self?.mapState(state)
            }
            .sink { [weak self] state in
                self?.handleStateUpdate(state)
            }
            .store(in: &cancellables)

        localSettings
            .publisher(for: \.tagsMigrationFinished)
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.updatePhotosNavigationBarItems()
            }
            .store(in: &cancellables)

        localSettings
            .publisher(for: \.isPhotosBackupEnabled)
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePhotosNavigationBarItems()
            }
            .store(in: &cancellables)

        tagsMigrationConstraintController.isMigrationAllowedPublisher
            .filter { $0.0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_, _) in
                self?.presentTagsMigrationSheetIfNeeded()
            }
            .store(in: &cancellables)

        guard !configuration.isPickingPhotos else {
            return
        }

        selectionController.updatePublisher
            .sink { [weak self] in
                self?.handleSelectionUpdate()
            }
            .store(in: &cancellables)

        userInfoController.userInfo
            .removeDuplicates()
            .sink { [weak self] info in
                guard let self, let info else { return }
                self.isPaidUser = info.isPaid
            }
            .store(in: &cancellables)
    }

    private func mapState(_ state: PhotoVolumeBootstrapState) -> PhotosRootViewState? {
        switch state {
        case .uninitialized:
            return nil
        case .inProgress:
            return .loading
        case let .failed(message):
            return .message(message)
        case let .finished(configuration):
            return .finished(configuration)
        }
    }

    private func handleStateUpdate(_ state: PhotosRootViewState) {
        self.state = state
        // Albums tab is only visible when photo volume is used and when user is not in picker mode (creating album)
        if case .finished = state, !configuration.isPickingPhotos {
            areAlbumsEnabled = true
        } else {
            areAlbumsEnabled = false
        }
    }

    private func handleSelectionUpdate() {
        if selectionController.isSelecting() {
            // Selection navigation is handled by the subview itself to avoid excessive SwiftUI redraws.
            // Search for usage of `PhotosRootNavigation` when modifying
            setNavigation(nil)
        } else {
            updatePhotosNavigationBarItems()
        }
    }

    private func setNavigation(_ navigation: PhotosRootNavigation?) {
        // In picker mode we only allow `.picker` navigation
        guard !configuration.isPickingPhotos else {
            return
        }

        // Without this check the view redraws redundantly
        if self.navigation != navigation {
            self.navigation = navigation
        }
    }

    func start() {
        bootstrapController.bootstrap()
    }

    func onAppear(streamConfiguration: PhotoStreamConfiguration) {
        self.streamConfiguration = streamConfiguration
    }

    func handle(galleryType: GalleryType) {
        if self.galleryType == galleryType { return }
        self.galleryType = galleryType
        switch galleryType {
        case .photos:
            updatePhotosNavigationBarItems()
        case .albums:
            let navigation = PhotosRootNavigation(
                title: nil,
                leading: .menu,
                trailing: [.plus]
            )
            setNavigation(navigation)
        }
    }

    private func updatePhotosNavigationBarItems() {
        guard galleryType == .photos else { return }
        let flag = localSettings.isPhotosBackupEnabled &&
        featureFlagsController.hasPhotosTagsMigration &&
        !localSettings.tagsMigrationFinished

        let navigation = PhotosRootNavigation.default(
            isPaidUser: isPaidUser,
            showTagMigrationSpinner: flag
        )
        setNavigation(navigation)
        presentTagsMigrationSheetIfNeeded()
    }

    private func presentTagsMigrationSheetIfNeeded() {
        guard
            galleryType == .photos,
            tagsMigrationConstraintController.isMigrationAllowed,
            !localSettings.isTagsMigrationSheetShown,
            featureFlagsController.hasPhotosTagsMigration,
            localSettings.isPhotosBackupEnabled
        else { return }
        let flag = !localSettings.tagsMigrationFinished
        if flag {
            coordinator.openTagsMigrationSheet()
            localSettings.isTagsMigrationSheetShown = true
        }
        if localSettings.tagsMigrationFinished {
            localSettings.isTagsMigrationSheetShown = true
        }
    }

    func handle(navigation: PhotosRootNavigation.Item) {
        switch navigation {
        case .cross:
            close()
        case .menu:
            coordinator.openMenu()
        case .plus:
            coordinator.openAlbumCreationView()
        case .cancel:
            selectionController.cancel()
        case .deselectAll:
            selectionController.deselectAll()
        case .subscribe:
            coordinator.openSubscription()
        case .tagMigrationSpinner:
            coordinator.presentTagMigrationBanner()
        }
    }

    func close() {
        coordinator.close()
    }
}
