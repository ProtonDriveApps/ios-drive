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
import SwiftUI
import ProtonCoreNetworking
import PDUIComponents
import PDLocalization

class SharedViewModel: ObservableObject, FinderViewModel, DownloadingViewModel, SortingViewModel, HasMultipleSelection, HasRefreshControl {
    typealias Identifier = NodeIdentifier

    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()

    // MARK: FinderViewModel
    let model: SharedModel
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
    private var isFetching = false
    private var isLoadingIndicatorNeeded = true

    let isSharedWithMe: Bool = false
    let hasPlusFunctionality = false

    var nodeName: String {
        self.listState.isSelecting ? self.titleDuringSelection() : screenName
    }

    var screenName: String {
        Localization.shared_screen_title
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
    let featureFlagsController: FeatureFlagsControllerProtocol

    func refreshControlAction() {
        fetchAllPages(isManualAction: true)
    }

    func refreshOnAppear() {
        model.loadFromCache()
        if !model.tower.didFetchAllShareURLs {
            fetchAllPages(isManualAction: false)
        }
    }

    func didScrollToBottom() { }

    // MARK: DownloadingViewModel
    var childrenDownloadCancellable: AnyCancellable?
    @Published var downloadProgresses: [ProgressTracker] = []

    // MARK: SortingViewModel
    @Published var sorting: SortPreference

    func onSortingChanged() {
        /* nothing, as this screen does not support per-page fetching */
    }

    // MARK: HasMultipleSelection
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active

    // MARK: others
    init(model: SharedModel, featureFlagsController: FeatureFlagsControllerProtocol) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        self.featureFlagsController = featureFlagsController

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
}

extension SharedViewModel {
    func fetchAllPages() {
        fetchAllPages(isManualAction: true)
    }

    private func fetchAllPages(isManualAction: Bool) {
        guard !isFetching else { return }
        isFetching = true

        if isManualAction || isLoadingIndicatorNeeded {
            isUpdating = true
        }

        Task {
            do {
                try await model.fetchSharedByUrl()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isUpdating = false
                    self.lastUpdated = Date()
                    self.isFetching = false
                    self.isLoadingIndicatorNeeded = false
                }
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.genericErrors.send(error)
                    self.isUpdating = false
                    self.isFetching = false
                }
            }
        }
    }

    func actionBarItems() -> [ActionBarButtonViewModel] {
        let isOfflineAvailablePossible = selectedNodes().contains(where: { $0.node.isDownloadable })
        return [
            .trashMultiple,
            isOfflineAvailablePossible ? .offlineAvailableMultiple : nil
        ].compactMap { $0 }
    }
}

extension MultipleSelectionModel {
    func unselectOnEmpty(for vm: any HasMultipleSelection) {
        let listState = Binding(
            get: { [weak vm] in (vm?.listState ?? .active) },
            set: { [weak vm] in vm?.listState = $0 })
        onEmptySelectable = { isEmpty in
            guard isEmpty else { return }
            listState.wrappedValue = .active
        }
    }
}

extension SharedViewModel: CancellableStoring { }
extension SharedViewModel: LayoutChangingViewModel { }

extension SharedModel: LayoutChanging {
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
