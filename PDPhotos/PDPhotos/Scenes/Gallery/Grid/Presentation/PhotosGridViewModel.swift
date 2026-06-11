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
import PDCore
import PDCoreIOS
import Foundation
import PDLocalization

protocol PhotosGridViewModelProtocol: ObservableObject {
    var sections: [PhotosGridViewSection] { get }
    var paginationStatus: PhotosPaginationStatus { get }
    var sectionsUpdatePublisher: AnyPublisher<[PhotosGridViewSection], Never> { get }
    var error: PassthroughSubject<Error?, Never> { get }
    var scrollToItem: AnyPublisher<AnyVolumeIdentifier, Never> { get }
    var isUsingCustomScroller: Bool { get }
    var footer: String { get }
    var footerError: String { get }
    var configuration: PhotosRootConfiguration { get }
    var selectionNumber: Int { get }
    var isRefreshing: Bool { get }
    var isRefreshingPublisher: AnyPublisher<Bool, Never> { get }
    var navigation: PhotosRootNavigation? { get }
    func didShowLastItem()
    func deselectAll()
    func selectionFinalized()
    func refresh()
    func onAppear()
    func stopObserving()
    func setUpdatedScrollOffset()
    func updateTopItem(_ item: PhotoGridViewItem)
    func handle(navigation: PhotosRootNavigation.Item)
    func reportListIsShown()
}

public enum PhotosPaginationStatus: Equatable {
    case loading
    case finished
    case error
}

final class PhotosGridViewModel: PhotosGridViewModelProtocol {
    private let controller: PhotosListControllerProtocol
    private let fetchingController: PhotosListFetchingControllerProtocol
    private let monthFormatter: MonthFormatter
    private let selectionController: PhotosSelectionController
    private let remoteAlbumFetchController: RemoteAlbumFetchControllerProtocol?
    private var cancellables = Set<AnyCancellable>()
    private let streamConfiguration: PhotoStreamConfiguration
    private let scrollerController: GridScrollerControllerProtocol?
    private let scrollToItemSubject = PassthroughSubject<AnyVolumeIdentifier, Never>()
    private let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>
    private let performanceMetricsController: PerformanceMetricsControllerProtocol?

    @Published var isRefreshing = false
    @Published var sections: [PhotosGridViewSection] = []
    @Published var paginationStatus: PhotosPaginationStatus = .finished
    @Published var isUsingCustomScroller = false
    @Published var navigation: PhotosRootNavigation?

    var sectionsUpdatePublisher: AnyPublisher<[PhotosGridViewSection], Never> {
        $sections.eraseToAnyPublisher()
    }
    var isRefreshingPublisher: AnyPublisher<Bool, Never> {
        $isRefreshing.eraseToAnyPublisher()
    }
    @Published var selectionNumber: Int = 0
    let configuration: PhotosRootConfiguration
    let error = PassthroughSubject<Error?, Never>()
    let footer: String = Localization.photos_screen_footer
    let footerError: String = Localization.photos_screen_footer_error
    var scrollToItem: AnyPublisher<AnyVolumeIdentifier, Never> {
        scrollToItemSubject.eraseToAnyPublisher()
    }

    init(
        controller: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        monthFormatter: MonthFormatter,
        configuration: PhotosRootConfiguration,
        selectionController: PhotosSelectionController,
        remoteAlbumFetchController: RemoteAlbumFetchControllerProtocol?,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>,
        streamConfiguration: PhotoStreamConfiguration,
        scrollerController: GridScrollerControllerProtocol?,
        performanceMetricsController: PerformanceMetricsControllerProtocol?
    ) {
        self.controller = controller
        self.monthFormatter = monthFormatter
        self.fetchingController = fetchingController
        self.configuration = configuration
        self.selectionController = selectionController
        self.scrollToTopPublisher = scrollToTopPublisher
        self.selectionNumber = selectionController.getPrimaryIds().count
        self.remoteAlbumFetchController = remoteAlbumFetchController
        self.streamConfiguration = streamConfiguration
        self.scrollerController = scrollerController
        self.performanceMetricsController = performanceMetricsController
        subscribeToUpdates()
        handleSelectionUpdate()
    }

    func onAppear() {
        remoteAlbumFetchController?.execute(input: .all)
    }

    func stopObserving() {
        controller.stopObserving()
    }

    func didShowLastItem() {
        fetchingController.loadNext()
    }

    func deselectAll() {
        selectionController.deselectAll()
    }

    func selectionFinalized() {
        selectionController.finalized()
    }

    func refresh() {
        Log.debug("Pull down to refresh photo listings", domain: .userAction)
        isRefreshing = true
        fetchingController.reset()
    }

    func setUpdatedScrollOffset() {
        scrollerController?.setScrolling()
    }

    func updateTopItem(_ item: PhotoGridViewItem) {
        scrollerController?.setCurrentItem(item)
    }

    private func subscribeToUpdates() {
        controller.sections
            .sink { [weak self] sections in
                let count = sections.reduce(0) { $0 + $1.photos.count }
                self?.performanceMetricsController?.updateTab(cacheCount: count, in: .photos)
                self?.handle(sections)
            }
            .store(in: &cancellables)

        fetchingController.errorPublisher
            .sink { [weak self] error in
                Log.error(error: error, domain: .photosProcessing)
                if PDPhotosConstants.buildType.isQaOrBelow {
                    self?.error.send(PhotosGridError.failedFetch)
                }
            }
            .store(in: &cancellables)

        selectionController.updatePublisher
            .sink { [weak self] _ in
                self?.handleSelectionUpdate()
            }
            .store(in: &cancellables)

        fetchingController.isLoading
            .sink { [weak self] isLoading in
                if !isLoading {
                    self?.isRefreshing = false
                }
            }
            .store(in: &cancellables)

        fetchingController.paginationStatus
            .assign(to: &$paginationStatus)

        scrollerController?.selectedId
            .sink { [weak self] id in
                self?.scrollToItemSubject.send(id)
            }
            .store(in: &cancellables)

        scrollerController?.items
            .map { !$0.isEmpty }
            .assign(to: &$isUsingCustomScroller)

        scrollToTopPublisher
            .filter { tab in
                tab == .photos
            }
            .compactMap { [weak self] _ in
                self?.sections.first?.items.first?.id
            }
            .sink { [weak self] id in
                self?.scrollToItemSubject.send(id)
            }
            .store(in: &cancellables)
    }

    private func handleSelectionUpdate() {
        let selectedIds = selectionController.getPrimaryIds()
        selectionNumber = selectedIds.count
        if selectionController.isSelecting() {
            let navigation = PhotosRootNavigation(
                title: Localization.general_selected(num: selectedIds.count),
                leading: .deselectAll(title: Localization.general_deselect_all, isEnabled: !selectedIds.isEmpty),
                trailing: [.cancel(Localization.general_cancel)]
            )
            setNavigation(navigation)
        } else {
            setNavigation(nil)
        }
    }

    private func setNavigation(_ navigation: PhotosRootNavigation?) {
        // Picker navigation is handled in the root. Search for `PhotosRootNavigation` for more details
        guard !configuration.isPickingPhotos else {
            return
        }

        if self.navigation != navigation {
            self.navigation = navigation
        }
    }

    private func handle(_ sections: [PhotosListSection]) {
        self.sections = sections.enumerated().map { makeSection(from: $0.element, index: $0.offset) }
    }

    private func makeSection(from section: PhotosListSection, index: Int) -> PhotosGridViewSection {
        PhotosGridViewSection(
            title: monthFormatter.formatMonth(from: section.month),
            isFirst: index == 0,
            items: section.photos.map(makePhoto)
        )
    }

    private func makePhoto(from photo: PhotoListing) -> PhotoGridViewItem {
        PhotoGridViewItem(
            photoId: photo.id.id,
            secondaryIds: photo.secondaryPhotos.map(\.id),
            volumeId: photo.id.volumeID,
            albumId: photo.albumId,
            captureTime: photo.captureTime,
            metadata: photo.metadata.map(makeMetadata)
        )

    }

    private func makeMetadata(from metadata: PhotoListing.Metadata) -> PhotoGridViewItem.Metadata {
        PhotoGridViewItem.Metadata(
            isShared: metadata.isShared,
            hasDirectShare: metadata.hasDirectShare,
            isVideo: metadata.isVideo,
            isDownloading: metadata.isDownloading,
            isAvailableOffline: metadata.isAvailableOffline,
            burstChildrenCount: metadata.burstChildrenCount,
            isFavorite: metadata.isFavorite
        )
    }

    func handle(navigation: PhotosRootNavigation.Item) {
        switch navigation {
        case .cross, .menu, .plus, .subscribe, .tagMigrationSpinner:
            // no-op, handled in root, only cancel and deselectAll are set above
            return
        case .cancel:
            selectionController.cancel()
        case .deselectAll:
            selectionController.deselectAll()
        }
    }

    func reportListIsShown() {
        performanceMetricsController?.reportTabToFirstItem(pageType: .photos)
    }
}
