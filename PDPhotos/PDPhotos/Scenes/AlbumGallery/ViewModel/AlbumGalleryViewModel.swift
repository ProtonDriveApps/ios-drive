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
import Combine
import Foundation
import PDCore
import PDCoreIOS

protocol AlbumGalleryViewModelProtocol: ObservableObject {
    var configuration: PhotosRootConfiguration { get }
    var currentTag: AlbumUITag { get }
    var gridViewModel: AlbumsGridViewModel { get }
    var isRefreshControlVisible: Bool { get }
    var isUpdating: Bool { get }
    var selectionNumber: Int { get }
    var shouldShowFilter: Bool { get }
    var shouldShowPlaceholder: Bool { get }
    var shouldShowSpinner: Bool { get }

    func onAppear()
    func list(albumType: AlbumUITag)
    func openAlbum(id: AnyVolumeIdentifier)
    func openAlbumCreation()
    func deselectAll()
    func selectionFinalized()
    func refresh()
    func makeAlbumGridItemViewModel(id: AnyVolumeIdentifier) -> AlbumGridItemViewModel
}

final class AlbumGalleryViewModel: AlbumGalleryViewModelProtocol {
    @Published private(set) var currentTag: AlbumUITag = .all
    @Published private(set) var gridViewModel: AlbumsGridViewModel
    @Published private(set) var isRefreshControlVisible: Bool = false
    private var isRefreshing = false
    @Published private(set) var isUpdating = false
    @Published private(set) var selectionNumber: Int
    @Published private(set) var shouldShowFilter: Bool = false
    @Published private(set) var shouldShowPlaceholder: Bool = false
    @Published private(set) var status = InitializedStatus.undetermined
    let configuration: PhotosRootConfiguration
    private let dependencies: Dependencies
    private var cancellables = Set<AnyCancellable>()
    private var withoutAlbum: Bool { gridViewModel.sections.first?.items.isEmpty ?? true }
    var shouldShowSpinner: Bool { status == .fetchingRemote && withoutAlbum }

    init(dependencies: Dependencies, configuration: PhotosRootConfiguration) {
        self.dependencies = dependencies
        self.configuration = configuration
        self.selectionNumber = dependencies.selectionController.getPrimaryIds().count
        self.gridViewModel = .init(sections: [])
        subscribeForUpdate()
    }

    func onAppear() {
        guard [.fetchFailed, .undetermined].contains(status) else { return }
        status = .fetchingRemote
        if !configuration.isPickingPhotos {
            dependencies.remoteAlbumFetchController.execute(input: .all)
        }
        list(albumType: currentTag)
    }

    func openAlbumCreation() {
        var shouldOpenInvitation: Bool = false
        if currentTag == .existing(.shared) {
            shouldOpenInvitation = true
        }
        dependencies.coordinator.openAlbumCreationView(shouldOpenInvitation: shouldOpenInvitation)
    }

    func list(albumType: AlbumUITag) {
        if isUpdating { return }
        isUpdating = true
        currentTag = albumType
        do {
            switch albumType {
            case .all:
                try dependencies.localAlbumListController.list(albumTag: nil)
            case .existing(let albumTag):
                try dependencies.localAlbumListController.list(albumTag: albumTag)
            }
        } catch {
            Log.error(error: error, domain: .albums)
        }
        isUpdating = false
    }

    func openAlbum(id: AnyVolumeIdentifier) {
        dependencies.coordinator.openAlbum(configuration: configuration, id: id)
    }

    func deselectAll() {
        dependencies.selectionController.deselectAll()
    }

    func selectionFinalized() {
        dependencies.selectionController.finalized()
    }

    func refresh() {
        let input = getCurrentListInput()
        refresh(input: input, isManualAction: true)
    }

    func makeAlbumGridItemViewModel(id: AnyVolumeIdentifier) -> AlbumGridItemViewModel {
        dependencies.albumGridItemViewModelFactory.makeViewModel(for: id)
    }

    private func refresh(input: ListAlbumsInput, isManualAction: Bool = false) {
        if isRefreshing { return }
        dependencies.remoteAlbumFetchController.execute(input: input)
        dependencies.invitationsController.refresh()
        if isManualAction {
            isRefreshControlVisible = true
        }
        isRefreshing = true
    }

    private func getCurrentListInput() -> ListAlbumsInput {
        switch currentTag {
        case .all:
            return .all
        case .existing(let albumTag):
            switch albumTag {
            case .myAlbums, .shared:
                return .own
            case .sharedWithMe:
                return .sharedWithMe
            }
        }
    }

    private func subscribeForUpdate() {
        dependencies.remoteAlbumFetchController.errorPublisher
            .sink { [weak self] error in
                self?.stopRefreshing()
                self?.status = .fetchFailed
                self?.dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
            }
            .store(in: &cancellables)
        dependencies.remoteAlbumFetchController.finishPublisher
            .sink { [weak self] in
                self?.stopRefreshing()
                self?.status = .fetchedRemote
                if self?.gridViewModel.sections.first?.items.isEmpty ?? true {
                    self?.shouldShowPlaceholder = true
                }
            }
            .store(in: &cancellables)
        dependencies.localAlbumListController.updatePublisher
            .sink { [weak self] list in
                guard let self else { return }
                if self.status == .fetchedRemote {
                    self.shouldShowPlaceholder = list.isEmpty
                }
                if currentTag == .all, list.isEmpty {
                    shouldShowFilter = false
                } else {
                    shouldShowFilter = true
                }
                self.gridViewModel = self.map(list: list)
            }
            .store(in: &cancellables)

        dependencies.selectionController.updatePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                self.selectionNumber = self.dependencies.selectionController.getPrimaryIds().count
            }
            .store(in: &cancellables)

        dependencies.invitationsChangeController.updatePublisher
            .sink { [weak self] _ in
                self?.refresh(input: .sharedWithMe)
            }
            .store(in: &cancellables)
    }

    private func stopRefreshing() {
        isRefreshing = false
        isRefreshControlVisible = false
    }

    private func map(list: [AlbumListing]) -> AlbumsGridViewModel {
        let sectionID: String? = gridViewModel.sections.first?.id
        return AlbumsGridViewModel(sections: [.init(id: sectionID, items: list)])

    }
}

extension AlbumGalleryViewModel {
    struct Dependencies {
        let albumGridItemViewModelFactory: CachingAlbumGridItemViewModelFactory
        let coordinator: AlbumGalleryCoordinatorProtocol
        let localAlbumListController: LocalAlbumListControllerProtocol
        let selectionController: PhotosSelectionController
        let metadataController: MetadataControllerProtocol
        let remoteAlbumFetchController: RemoteAlbumFetchControllerProtocol
        let thumbnailContainer: ThumbnailsControllersContainerProtocol
        let userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
        let invitationsController: AlbumInvitationsControllerProtocol
        let invitationsChangeController: PendingInvitationsChangeControllerProtocol

        init(
            coordinator: AlbumGalleryCoordinatorProtocol,
            context: NSManagedObjectContext,
            localAlbumListController: LocalAlbumListControllerProtocol,
            selectionController: PhotosSelectionController,
            metadataController: MetadataControllerProtocol,
            remoteAlbumFetchController: RemoteAlbumFetchControllerProtocol,
            thumbnailContainer: ThumbnailsControllersContainerProtocol,
            invitationsController: AlbumInvitationsControllerProtocol,
            invitationsChangeController: PendingInvitationsChangeControllerProtocol
        ) {

            self.coordinator = coordinator
            self.localAlbumListController = localAlbumListController
            self.selectionController = selectionController
            self.metadataController = metadataController
            self.remoteAlbumFetchController = remoteAlbumFetchController
            self.thumbnailContainer = thumbnailContainer
            self.invitationsController = invitationsController
            self.invitationsChangeController = invitationsChangeController

            self.albumGridItemViewModelFactory = CachingAlbumGridItemViewModelFactory(factory: { id in
                let repository = AlbumRepository(albumID: id, managedObjectContext: context)
                return .init(
                    albumID: id,
                    albumRepository: repository,
                    debounceResource: CommonLoopDebounceResource(),
                    metadataController: metadataController,
                    thumbnailContainer: thumbnailContainer
                )
            })
        }
    }

    enum InitializedStatus {
        case undetermined
        case fetchingRemote
        case fetchedRemote
        case fetchFailed
    }
}
