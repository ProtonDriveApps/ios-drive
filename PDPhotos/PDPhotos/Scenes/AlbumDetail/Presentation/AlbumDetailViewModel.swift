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
import PDCore
import PDCoreIOS
import PDLocalization
import SwiftUI
import ProtonCoreNetworking

struct AlbumDetailConstants {
    static let add = Localization.general_add
    static let edit = Localization.general_edit
    static let share = Localization.general_share
    static let cancel = Localization.general_cancel
    static let deselectAll = Localization.general_deselect_all
    static let pullToRefresh = Localization.text_pull_to_refresh

    static let coverHeight: CGFloat = 226
}

final class AlbumDetailViewModel: ObservableObject {
    @Published private(set) var isDeletingAlbum = false
    @Published private(set) var selectionNumber: Int

    /// Initialize with the lowest permission
    @Published private(set) var albumRole: Role = .viewer
    @Published var isAddingPhotos = false
    @Published var isSelecting = false
    @Published var showNavigationTitle = false
    @Published var showSpinner = false

    let configuration: PhotosRootConfiguration
    private let dependencies: Dependencies
    private var album: Album?
    private var cancellables = Set<AnyCancellable>()
    private(set) var shouldOpenInvitation: Bool
    private var coverViewModel: AlbumDetailCoverViewModel?
    private var infoViewModel: AlbumDetailInfoViewModel?
    private var gridViewModel: AlbumDetailGridViewModel?
    private let refreshThreshold: Double = 50

    /// If the user's finger is still on the screen—even after exceeding the threshold again
    /// the data shouldn't refresh a second time
    private var canRefresh = true
    /// Is refreshing photo list
    private var isRefreshing = false

    init(
        dependencies: Dependencies,
        configuration: PhotosRootConfiguration,
        shouldOpenInvitation: Bool
    ) {
        self.configuration = configuration
        self.dependencies = dependencies
        self.selectionNumber = dependencies.selectionController.getPrimaryIds().count
        self.shouldOpenInvitation = shouldOpenInvitation
        subscribeToUpdates()
    }

    func onAppear() {
        dependencies.albumRepository.start()
    }

    func tapBack() {
        dependencies.coordinator.pop()
    }

    func tapMore() {
        guard let album else { return }
        if albumRole.canAdministrate {
            dependencies.coordinator.openMoreActionSheet(
                renameParameter: .init(
                    albumID: album.identifier,
                    albumName: album.clearName ?? "",
                    originalHash: album.nodeHash
                ),
                renameHandler: { [weak self] error in
                    if let error {
                        self?.dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
                    } else {
                        let message = Localization.album_edit_saved
                        self?.dependencies.userMessageHandler.handleSuccess(message)
                    }
                },
                deleteAlbumHandler: { [weak self] in
                    guard let self, let album = self.album else { return }
                    let identifiers = gridViewModel?.gridViewItems.map(\.id) ?? []
                    Task {
                       try await self.dependencies.deletionFlowController.presentAlert(
                            parameters: .init(
                                photoIdentifiers: identifiers,
                                album: album
                            ),
                            deletingCallback: { [weak self] in
                                self?.dependencies.photosGridViewModel.stopObserving()
                            }
                        )
                    }
                },
                leaveAlbumHandler: albumRole == .owner ? nil : { [weak self] in
                    guard let self, let album = self.album else { return }
                    self.leaveAlbum(album)
                }
            )
        } else {
            dependencies.photosGridViewModel.reportListIsShown()
            dependencies.coordinator.openMoreActionSheetForGuest(leaveAlbumHandler: { [weak self] in
                guard let self, let album = self.album else { return }
                self.leaveAlbum(album)
            })
        }
    }

    private func leaveAlbum(_ album: Album) {
        dependencies.albumLeaveFlowController.presentAlert(
            parameters: .init(album: album),
            leavingCallback: { [weak self] in
                // Prevent grid view refresh due to album and contextShare are deleted
                self?.dependencies.photosGridViewModel.stopObserving()
            }
        )
    }

    func deselectAll() {
        dependencies.selectionController.deselectAll()
    }

    func tapCancelSelection() {
        dependencies.selectionController.cancel()
    }

    func selectionFinalized() {
        dependencies.selectionController.finalized()
    }

    func getCoverViewModel() -> AlbumDetailCoverViewModel {
        if let coverViewModel { return coverViewModel }
        let vm: AlbumDetailCoverViewModel = .init(
            dependencies: .init(
                albumRepository: dependencies.albumRepository,
                thumbnailDownloader: dependencies.thumbnailDownloader,
                contentController: dependencies.contentController,
                metadataController: dependencies.metadataController
            )
        )
        coverViewModel = vm
        return vm
    }

    func getInfoViewModel() -> AlbumDetailInfoViewModel {
        if let infoViewModel { return infoViewModel }
        let viewModel = AlbumDetailInfoViewModel(
            configuration: configuration,
            dependencies: .init(
                addPhotoSelectionController: dependencies.addPhotoSelectionController,
                albumRepository: dependencies.albumRepository,
                coordinator: dependencies.coordinator,
                featureFlagsController: dependencies.featureFlagsController,
                inviteeListLoadController: dependencies.inviteeListLoadController,
                invitationResultController: InvitationResultController(),
                userMessageHandler: dependencies.userMessageHandler,
                copyToStreamController: dependencies.copyToStreamController
            ),
            shouldOpenInvitation: shouldOpenInvitation
        )
        self.infoViewModel = viewModel
        return viewModel
    }

    func getGridViewModel() -> AlbumDetailGridViewModel {
        if let gridViewModel { return gridViewModel }
        let viewModel = AlbumDetailGridViewModel(
            dependencies: .init(
                itemViewModelFactory: dependencies.itemViewModelFactory,
                photosGridViewModel: dependencies.photosGridViewModel
            )
        )
        gridViewModel = viewModel
        return viewModel
    }

    func title(offset: Double) -> String {
        AlbumDetailConstants.pullToRefresh
    }

    func offsetIsChanged(offset: Double) {
        if offset > refreshThreshold, canRefresh {
            canRefresh = false
            isRefreshing = true
            if let id = album?.identifier {
                dependencies.metadataController.loadImmediatelly([id], forceToRefresh: true)
            }
            dependencies.photosGridViewModel.refresh()
        }
        if offset < 2 { canRefresh = true }
        showSpinner = isRefreshing || !canRefresh
    }
}

// MARK: - Navigation bar
extension AlbumDetailViewModel {
    var navigationTitle: String {
        let isPickingPhotos = configuration.isPickingPhotos
        if isSelecting, !isPickingPhotos {
            let num = dependencies.selectionController.getPrimaryIds().count
            return Localization.general_selected(num: num)
        } else {
            let title = album?.clearName ?? ""
            return showNavigationTitle ? title : ""
        }
    }

    var leadingItem: NavigationItem {
        let isPickingPhotos = configuration.isPickingPhotos
        if isSelecting, !isPickingPhotos {
            return .deselectAll
        }
        return .back
    }

    var trailingItem: NavigationItem {
        if configuration.isPickingPhotos {
            return .empty
        }
        return isSelecting ? .cancel : .more
    }
}

// MARK: - Private functions
extension AlbumDetailViewModel {
    private func subscribeToUpdates() {
        dependencies.albumRepository.updatePublisher
            .removeDuplicates()
            .sink { [weak self] album in
                guard let self, let album else { return }
                self.album = album
                albumRole = album.role
            }
            .store(in: &cancellables)
        dependencies.selectionController.updatePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                self.selectionNumber = self.dependencies.selectionController.getPrimaryIds().count
                self.isSelecting = self.dependencies.selectionController.isSelecting()
                self.dependencies.coordinator.enableSwipeBack(isEnabled: !isSelecting)
            }
            .store(in: &cancellables)
        dependencies.addPhotoSelectionController.finalizedPublisher
            .sink { [weak self] allSelectedIDs in
                self?.handleAddPhoto(selectedIDs: allSelectedIDs)
            }
            .store(in: &cancellables)
        dependencies.deletionFlowController.deletingPublisher
            .assign(to: &$isDeletingAlbum)
        dependencies.albumLeaveFlowController.leavingPublisher
            .assign(to: &$isDeletingAlbum)
        dependencies.addToAlbumController.isAdding
            .assign(to: &$isAddingPhotos)
        dependencies.photosGridViewModel.isRefreshingPublisher
            .sink { [weak self] value in
                self?.isRefreshing = value
            }
            .store(in: &cancellables)
    }
}

// MARK: - Selection controller handler
extension AlbumDetailViewModel {
    private func handleAddPhoto(selectedIDs: Set<PhotoListingId>) {
        dependencies.coordinator.dismissPhotoPicker { [weak self] in
            guard let self, let albumID = album?.identifier else {
                return
            }

            let primaryIds = Set(selectedIDs.map(\.primary))
            dependencies.addToAlbumController.add(primaryIds: primaryIds, to: albumID)
        }
    }
}
