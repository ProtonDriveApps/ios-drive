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

import Foundation
import Combine
import PDCore
import PDCoreIOS
import PDUIComponents
import PDLocalization

final class OfflineAvailableViewModel: ObservableObject, FinderViewModel, DownloadingViewModel, HasMultipleSelection {
    typealias Identifier = NodeIdentifier

    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()

    // MARK: FinderViewModel
    let model: OfflineAvailableModel
    let sorting: SortPreference
    func subscribeToSort() { }
    var childrenCancellable: AnyCancellable?
    var lockedStateCancellable: AnyCancellable?
    var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>? = nil
    var isSharedWithMe: Bool = false
    var isRoot: Bool = true
    let hasPlusFunctionality = false
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = [] {
        didSet { selection.updateSelectable(Set(permanentChildren.map(\.node.identifier))) }
    }
    @Published var isVisible: Bool = true
    let genericErrors = ErrorRegulator()

    @Published var isUpdating: Bool = false
    
    var nodeName: String {
        self.listState.isSelecting ? self.titleDuringSelection() : Localization.available_offline_title
    }
    
    var trailingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.cancel] : [.apply(title: "", disabled: true)]
    }
    
    var leadingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.apply(title: selection.selectAllText, disabled: false)] : [.menu]
    }
    
    let lastUpdated: Date = .distantFuture // not relevant
    let supportsSortingSwitch: Bool = false
    let permanentChildrenSectionTitle: String = ""

    let supportsLayoutSwitch = true
    let featureFlagsController: FeatureFlagsControllerProtocol
    @Published var topBanner: String?

    func refreshControlAction() {
        model.loadFromCache()
    }
    func refreshOnAppear() {
        refreshControlAction()
    }
    func didScrollToBottom() { }
    
    func selected(file: File) { }
    
    // MARK: DownloadingViewModel
    var childrenDownloadCancellable: AnyCancellable?
    @Published var downloadProgresses: [ProgressTracker] = []
    
    // MARK: HasMultipleSelection
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active
    private let validator: iOSSupportedSharesValidator
    private let warningViewModel: PhotosMigrationWarningViewModelProtocol

    // MARK: others
    init(model: OfflineAvailableModel, featureFlagsController: FeatureFlagsControllerProtocol, warningViewModel: PhotosMigrationWarningViewModelProtocol) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        self.featureFlagsController = featureFlagsController
        self.validator = iOSSupportedSharesValidator(storage: model.tower.storage)
        self.warningViewModel = warningViewModel

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

        warningViewModel.warning
            .assign(to: &$topBanner)
    }

    func actionBarItems() -> [ActionBarButtonViewModel] {
        [.trashMultiple, .offlineAvailableMultiple]
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
}

extension OfflineAvailableViewModel: CancellableStoring { }
extension OfflineAvailableViewModel: LayoutChangingViewModel { }

extension OfflineAvailableModel: LayoutChanging {
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
