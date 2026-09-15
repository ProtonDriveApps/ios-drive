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

import Combine
import PDCore
import PDCoreIOS
import SwiftUI
import ProtonCoreNetworking
import PDUIComponents
import PDLocalization

class SharedByMeViewModel: ObservableObject, FinderViewModel, DownloadingViewModel, SortingViewModel, HasMultipleSelection, HasRefreshControl, CancellableStoring, LayoutChangingViewModel {
    typealias Identifier = NodeIdentifier

    // MARK: FinderViewModel
    var cancellables = Set<AnyCancellable>()
    @Published var layout: Layout
    let model: SharedByMeModel
    var childrenCancellable: AnyCancellable?
    var lockedStateCancellable: AnyCancellable?
    var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>? = nil
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []  {
        didSet { selection.updateSelectable(Set(permanentChildren.map(\.node.identifier))) }
    }
    var isVisible: Bool = true
    let genericErrors = ErrorRegulator()
    @Published var isUpdating: Bool = false
    private var isUpdatingSilent: Bool = false
    private var isLoadingIndicatorNeeded = true

    private var isFetching = false
    let isSharedWithMe: Bool = false
    let hasPlusFunctionality = false
    var nodeName: String {
        self.listState.isSelecting ? self.titleDuringSelection() : screenName
    }
    var screenName: String {
        Localization.shared_by_me_screen_title
    }
    var trailingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.cancel] : []
    }
    var leadingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.apply(title: selection.selectAllText, disabled: false)] : [.menu]
    }
    let currentTab: TabBarItem? = .shared
    var isRoot: Bool { true }
    public private(set) var lastUpdated: Date = .distantFuture
    let supportsSortingSwitch: Bool = true
    var permanentChildrenSectionTitle: String { self.sorting.title }
    let supportsLayoutSwitch = true
    let featureFlagsController: FeatureFlagsControllerProtocol
    // MARK: DownloadingViewModel
    var childrenDownloadCancellable: AnyCancellable?
    let progressTrackersController: ProgressTrackersControllerProtocol

    lazy var nodeDownloadedResource: NodeDownloadedResource = {
        NodeDownloadedResource(managedObjectContext: model.tower.storage.newBackgroundContext())
    }()
    // MARK: SortingViewModel
    @Published var sorting: SortPreference
    // MARK: HasMultipleSelection
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active
    private let validator: iOSSupportedSharesValidator

    init(model: SharedByMeModel, featureFlagsController: FeatureFlagsControllerProtocol, progressTrackersController: ProgressTrackersControllerProtocol) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        self.featureFlagsController = featureFlagsController
        self.validator = iOSSupportedSharesValidator(storage: model.tower.storage)
        self.progressTrackersController = progressTrackersController

        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToChildrenDownloading()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        model.errorSubject
            .sink { [weak self] error in
                self?.genericErrors.send(error)
            }
            .store(in: &cancellables)
    }

    func didScrollToBottom() {
        /* nothing, as this screen does not support per-page fetching */
    }

    func onSortingChanged() {
        /* nothing, as this screen does not support per-page fetching */
    }

    func refreshControlAction() {
        fetchInitial()
    }

    func refreshOnAppear() {
        if model.tower.storage.finishedFetchingSharedByMe == nil {
            fetchInitial()
        } else {
            fetchUpdate()
        }
    }

    private func fetchInitial() {
        guard !isUpdatingSilent else { return }
        isUpdatingSilent = true

        Task {
            await showLoadingIndicator()

            do {
                try await model.fetchSharedByMe()
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
                await showLoadingIndicatorIfNeeded()
                try await model.fetchSharedByMe()
                await handleListingSuccess()
            } catch {
                await handleListingError(error)
            }
        }
    }

    @MainActor
    private func handleListingSuccess() {
        self.isUpdatingSilent = false
        self.isUpdating = false
        self.isLoadingIndicatorNeeded = false
        self.lastUpdated = Date()
        self.model.tower.storage.finishedFetchingSharedByMe = true
        self.model.loadFromCache()
        self.subscribeToChildren()
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
                self.permanentChildren = activeSorted.filter { self.validator.isValid($0.shareID) }.map(NodeWrapper.init)
            }
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
        let isOfflineAvailablePossible = selectedNodes().contains(where: { $0.node.isDownloadable })
        return [
            .trashMultiple,
            isOfflineAvailablePossible ? .offlineAvailableMultiple : nil
        ].compactMap { $0 }
    }

    func reportListIsShown() {
        model.tower.performanceMetricsController?.reportTabToFirstItem(pageType: .sharedByMe)
    }
}

extension SharedByMeModel: LayoutChanging {
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
