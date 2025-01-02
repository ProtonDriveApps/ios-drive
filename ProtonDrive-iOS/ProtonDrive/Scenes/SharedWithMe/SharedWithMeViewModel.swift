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
import PDUIComponents

class SharedWithMeViewModel: ObservableObject, FinderViewModel, DownloadingViewModel, SortingViewModel, HasMultipleSelection, HasRefreshControl {
    typealias Identifier = NodeIdentifier

    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()
    private let starter: SharedWithMeStarter
    private let retriever: SharedLinkRetriever
    private let volumeIdsController: SharedVolumeIdsController
    private var isLoadingIndicatorNeeded = true

    // MARK: FinderViewModel
    let model: SharedWithMeModel
    var childrenCancellable: AnyCancellable?
    var lockedStateCancellable: AnyCancellable?
    var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []  {
        didSet { selection.updateSelectable(Set(permanentChildren.map(\.node.identifier))) }
    }
    var isVisible: Bool = true
    let genericErrors = ErrorRegulator()
    @Published var isUpdating: Bool = false

    let isSharedWithMe: Bool = true
    let isSharedWithMeRoot: Bool = true
    let hasPlusFunctionality = false
    private var isUpdatingSilent: Bool = false

    var nodeName: String {
        self.listState.isSelecting ? self.titleDuringSelection() : "Shared with me"
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
    @Published var downloadProgresses: [ProgressTracker] = []

    // MARK: SortingViewModel
    @Published var sorting: SortPreference

    func onSortingChanged() {
        /* nothing, as this screen does not support per-page fetching */
    }

    var featureFlagsController: FeatureFlagsControllerProtocol

    // MARK: HasMultipleSelection
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active

    // MARK: others
    init(model: SharedWithMeModel, starter: SharedWithMeStarter, retriever: SharedLinkRetriever, featureFlagsController: FeatureFlagsControllerProtocol, volumeIdsController: SharedVolumeIdsController) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.starter = starter
        self.retriever = retriever
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        self.featureFlagsController = featureFlagsController
        self.volumeIdsController = volumeIdsController

        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToChildrenDownloading()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()
        subscribeToErrors()
    }

    private func subscribeToErrors() {
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
                try await starter.bootstrap()
                try await retriever.retrieve()
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
            try await retriever.retrieve()
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
