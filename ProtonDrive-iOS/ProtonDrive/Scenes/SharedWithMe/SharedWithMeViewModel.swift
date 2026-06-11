// Copyright (c) 2024 Proton AG
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

import Foundation
import Combine
import PDCore
import PDCoreIOS
import PDUIComponents
import PDLocalization

class SharedWithMeViewModel: ObservableObject, FinderViewModel, DownloadingViewModel, SortingViewModel, HasMultipleSelection, HasRefreshControl {
    typealias Identifier = NodeIdentifier

    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()
    private let starter: SharedWithMeStarter & SharedLinkIdDataSource
    private let retriever: SharedLinkRetriever
    private let bookmarksScanner: BookmarksScannerInteractorProtocol
    private let volumeIdsController: SharedVolumeIdsController
    private var isLoadingIndicatorNeeded = true

    // MARK: FinderViewModel
    let model: SharedWithMeModel
    private let pendingInvitationsContainer: PendingInvitationsStatusContainer
    private let bookmarksContainer: BookmarkContainer
    let pendingInvitationsViewModel: PendingInvitationsStatusViewModel
    var childrenCancellable: AnyCancellable?
    var lockedStateCancellable: AnyCancellable?
    var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []  {
        didSet {
            let selectable = Set(permanentChildren.map(\.node.identifier).filter(\.isNotBookmark))
            selection.updateSelectable(selectable)
        }
    }
    var isVisible: Bool = true
    let isRoot = true
    let genericErrors = ErrorRegulator()
    @Published var isUpdating: Bool = false

    let isSharedWithMe: Bool = true
    let isSharedWithMeRoot: Bool = true
    let hasPlusFunctionality = false
    private var isUpdatingSilent: Bool = false
    let currentTab: TabBarItem? = .sharedWithMe 

    var nodeName: String {
        self.listState.isSelecting ? self.titleDuringSelection() : Localization.tab_bar_title_shared_with_me
    }

    var trailingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.cancel] : [.apply(title: "", disabled: true)]
    }

    var leadingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.apply(title: selection.selectAllText, disabled: false)] : [.menu]
    }

    public private(set) var lastUpdated: Date = .distantFuture
    let supportsSortingSwitch: Bool = true
    var permanentChildrenSectionTitle: String { self.sorting.title }

    let supportsLayoutSwitch = true

    func didScrollToBottom() { }

    // MARK: DownloadingViewModel
    var childrenDownloadCancellable: AnyCancellable?
    let progressTrackersController: ProgressTrackersControllerProtocol

    lazy var nodeDownloadedResource: NodeDownloadedResource = {
        NodeDownloadedResource(managedObjectContext: model.tower.storage.newBackgroundContext())
    }()

    // MARK: SortingViewModel
    @Published var sorting: SortPreference

    func onSortingChanged() {
        /* nothing, as this screen does not support per-page fetching */
    }

    var provedEmpty: Bool {
        noChildren && provedChildrenCount && pendingInvitationsViewModel.viewState == nil
    }

    let featureFlagsController: FeatureFlagsControllerProtocol

    // MARK: HasMultipleSelection
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active

    // MARK: others
    init(
        model: SharedWithMeModel,
        starter: SharedWithMeStarter & SharedLinkIdDataSource,
        retriever: SharedLinkRetriever,
        pendingInvitationsContainer: PendingInvitationsStatusContainer,
        bookmarksContainer: BookmarkContainer,
        featureFlagsController: FeatureFlagsControllerProtocol,
        volumeIdsController: SharedVolumeIdsController,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>,
        progressTrackersController: ProgressTrackersControllerProtocol
    ) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.starter = starter
        self.retriever = retriever
        self.bookmarksScanner = bookmarksContainer.makeBookmarksScanner()
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        self.featureFlagsController = featureFlagsController
        self.volumeIdsController = volumeIdsController
        self.pendingInvitationsContainer = pendingInvitationsContainer
        self.pendingInvitationsViewModel = pendingInvitationsContainer.makePendingInvitationsStatusViewModel()
        self.bookmarksContainer = bookmarksContainer
        self.progressTrackersController = progressTrackersController

        self.scrollToTopPublisher = scrollToTopPublisher
        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToChildrenDownloading()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()
        subscribeToUpdate()
    }

    func subscribeToChildren() {
        self.childrenCancellable?.cancel()
        self.childrenCancellable = self.model.children()
            .filter { [weak self] _, _ in
                // reordering is heavy operation, so we do not want to perform it on all the folders at once when the app-wide setting is changed
                // instead we will call refreshOnAppear() when the view is back visible
                self?.isVisible == true
            }
            .removeDuplicates(by: { previous, current in
                return previous.0 == current.0 && previous.1 == current.1
            })
            .sink { [weak self] activeSorted, _ in
                guard let self = self, self.isVisible else { return }
                let children = activeSorted.filter(dropBookmarksIfDisabled)
                self.model.tower.performanceMetricsController?.updateTab(cacheCount: children.count, in: .sharedWithMe)
                self.permanentChildren = children.map(NodeWrapper.init)
            }
    }

    private func dropBookmarksIfDisabled(_ node: Node) -> Bool {
        guard node is CoreDataBookmark else {
            return true
        }

        return featureFlagsController.hasBookmarks
    }

    private func subscribeToUpdate() {
        model.errorSubject
            .sink { [weak self] error in
                self?.genericErrors.send(error)
            }
            .store(in: &cancellables)
    }

    func refreshControlAction() {
        fetchInitial()
    }

    func refreshOnAppear() {
        if model.tower.storage.finishedFetchingSharedWithMe == nil {
            fetchInitial()
        } else {
            fetchUpdate()
        }
        // When root sharedWithMe is displayed, all shares' folders are closed. So we can resign volume events polling.
        volumeIdsController.resignActiveSharedVolume()
    }

    private func fetchInitial() {
        guard !isUpdatingSilent else { return }
        isUpdatingSilent = true

        Task {
            await showLoadingIndicator()

            do {
                await pendingInvitationsViewModel.onViewDidAppear()
                try await starter.bootstrap()
                try await retriever.retrieve(dataSource: starter)
                try await bookmarksScanner.scan()
                await handleListingSuccess()
            } catch {
                await handleListingError(error)
            }
        }
    }

    private func fetchUpdate() {
        guard !isUpdatingSilent else { return }
        isUpdatingSilent = true

        Task {
            do {
                try await starter.bootstrap()
                await fetchUpdateMetadata()
            } catch {
                await handleListingError(error)
            }
        }
    }

    private func fetchUpdateMetadata() async {
        do {
            await showLoadingIndicatorIfNeeded()
            try await retriever.retrieve(dataSource: starter)
            try await bookmarksScanner.scan()
            await pendingInvitationsViewModel.onViewDidAppear()
            await hideLoadingIndicator()
            await handleListingSuccess()
        } catch {
            await handleListingError(error)
        }
    }

    @MainActor
    private func handleListingSuccess() {
        self.isUpdatingSilent = false
        self.isUpdating = false
        self.isLoadingIndicatorNeeded = false
        self.lastUpdated = Date()
        self.model.tower.storage.finishedFetchingSharedWithMe = true
        self.model.loadFromCache()
        self.subscribeToChildren()
    }

    @MainActor
    private func handleListingError(_ error: Error) {
        self.genericErrors.send(error)
        self.isUpdatingSilent = false
        self.isUpdating = false
    }

    @MainActor
    private func showLoadingIndicator() {
        self.isUpdating = true
    }

    @MainActor
    private func showLoadingIndicatorIfNeeded() {
        if isLoadingIndicatorNeeded {
            isUpdating = true
        }
    }

    @MainActor
    private func hideLoadingIndicator() {
        self.isUpdating = false
    }

    func actionBarItems() -> [ActionBarButtonViewModel] {
        let onlyOneSelected = selectedNodes().count == 1
        let isOfflineAvailablePossible = selectedNodes().contains(where: { $0.node.isDownloadable })
        return [
            onlyOneSelected ? .removeMe : nil,
            isOfflineAvailablePossible ? .offlineAvailableMultiple : nil
        ].compactMap { $0 }
    }

    func reportListIsShown() {
        model.tower.performanceMetricsController?.reportTabToFirstItem(pageType: .sharedWithMe)
    }
}

extension SharedWithMeViewModel: CancellableStoring { }
extension SharedWithMeViewModel: LayoutChangingViewModel { }

extension SharedWithMeModel: LayoutChanging {
    public var layout: LayoutPreference {
        tower.layout
    }

    public var layoutPublisher: AnyPublisher<LayoutPreference, Never> {
        tower.layoutPublisher
    }

    public func changeLayoutPreference(to newLayout: LayoutPreference) {
        tower.changeLayoutPreference(to: newLayout)
    }
}

extension SharedWithMeViewModel {
    func removeBookmark(_ bookmark: PDCore.CoreDataBookmark) {
        bookmarksContainer
            .makeBookmarkManagerViewMode(for: bookmark)
            .deleteBookmark()
    }

    func copyBookmarkUrl(_ bookmark: PDCore.CoreDataBookmark) {
        bookmarksContainer
            .makeBookmarkManagerViewMode(for: bookmark)
            .copyBookmarkUrl()
    }
}

private extension NodeIdentifier {
    var isBookmark: Bool {
        volumeID == "bookmark"
    }

    var isNotBookmark: Bool {
        !isBookmark
    }
}
