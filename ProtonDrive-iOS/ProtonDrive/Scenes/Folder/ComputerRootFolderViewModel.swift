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
import PDCore
import PDCoreIOS
import SwiftUI
import PDUIComponents
import PDLocalization

class ComputerRootFolderViewModel: ObservableObject, FinderViewModel, FetchingViewModel, HasRefreshControl, UploadingViewModel, DownloadingViewModel, SortingViewModel {
    typealias FolderErrorModel = FolderModel & FinderErrorModel
    typealias Identifier = NodeIdentifier
    private let localSettings: LocalSettings
    private let volumeIdsController: SharedVolumeIdsController
    let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?

    // MARK: FinderViewModel
    let model: FolderModel
    var cancellables = Set<AnyCancellable>()
    var childrenCancellable: AnyCancellable?
    var lockedStateCancellable: AnyCancellable?
    var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []

    @Published var layout: Layout

    var isVisible: Bool = true
    let isRoot = true

    var isSharedWithMe: Bool
    let hasPlusFunctionality: Bool

    let uploadErrors = ErrorRegulator()
    let genericErrors = ErrorRegulator()

    var nodeName: String {
        guard let node = node else {
            return NodeCellWithProgressConfiguration.unknownNamePlaceholder
        }
        return node.decryptedName
    }

    @Published var isUpdating = false

    var trailingNavBarItems: [NavigationBarButton] {
        return []
    }

    var leadingNavBarItems: [NavigationBarButton] {
        return [.virtualBack]
    }

    var supportsSortingSwitch: Bool = true
    var permanentChildrenSectionTitle: String { self.sorting.title }

    let supportsLayoutSwitch = true
    let featureFlagsController: FeatureFlagsControllerProtocol
    let topBanner: String? = nil

    @Published var isUploadDisclaimerVisible: Bool = false

    func closeUploadDisclaimer() {
        localSettings.isUploadingDisclaimerActive = false
    }

    // MARK: FetchingViewModel
    @Published var lastUpdated = Date.distantPast
    var fetchFromAPICancellable: AnyCancellable?

    // MARK: UploadingViewModel
    var childrenUploadCancellable: AnyCancellable?
    let showsUploadsErrorBanner: Bool = true
    @Published var uploadsCount: Int = 0
    @Published var uploadProgresses: UploadProgresses = [:]
    var failedCount: Int = 0
    let nodeStatePolicy: NodeStatePolicy

    // MARK: DownloadingViewModel
    var childrenDownloadCancellable: AnyCancellable?
    @Published var downloadProgresses: [ProgressTracker] = []

    // MARK: SortingViewModel
    @Published var sorting: SortPreference

    func refreshOnAppear() {
        self.layout = .init(preference: self.model.layout)
        self.model.loadFromCache()
        self.fetchPages()

        if isSharedWithMe {
            // Mark volume active so events are triggered more often
            volumeIdsController.setActiveSharedVolume(id: model.node.volumeID)
        }
    }

    func didScrollToBottom() {
        if self.refreshMode == .fetchPageByRequest {
            self.fetchNextPageFromAPI()
        }
    }

    // MARK: HasMultipleSelection
    private var multiSelectWasActivatedOnce: Bool = false
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active

    // MARK: others

    init(
        localSettings: LocalSettings,
        model: FolderErrorModel,
        node: Folder,
        nodeStatePolicy: NodeStatePolicy,
        featureFlagsController: FeatureFlagsControllerProtocol,
        isSharedWithMe: Bool = false,
        volumeIdsController: SharedVolumeIdsController,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?
    ) {
        self.localSettings = localSettings
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        self.nodeStatePolicy = nodeStatePolicy
        self.featureFlagsController = featureFlagsController
        self.isSharedWithMe = isSharedWithMe
        self.volumeIdsController = volumeIdsController
        self.scrollToTopPublisher = scrollToTopPublisher
        hasPlusFunctionality = !isSharedWithMe || node.getNodeRole() != .viewer

        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToChildrenUploading()
        self.subscribeToChildrenDownloading()
        self.subscribeToLayoutChanges()
        self.subscribeToUserInfoUpdates()
        setupLockedStateBannerVisibility()
        setupUploadBannerVisibility()

        $permanentChildren
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] permanent in
                self?.selection.updateSelectable(Set(permanent.map(\.node.identifier)))
            }
            .store(in: &cancellables)

        $listState
            .sink { [weak self] state in
                if state == .selecting {
                    self?.multiSelectWasActivatedOnce = true
                }
            }
            .store(in: &cancellables)

        model.errorSubject
            .sink { [weak self] error in
                self?.genericErrors.stream.send(error)
            }
            .store(in: &cancellables)
    }

    private func setupUploadBannerVisibility() {
        localSettings.publisher(for: \.isUploadingDisclaimerActive)
            .sink { [weak self] value in
                self?.isUploadDisclaimerVisible = value
            }
            .store(in: &cancellables)
    }

    func actionBarItems() -> [ActionBarButtonViewModel] {
        return []
    }

    func childViewModel(for node: PDCore.Node) -> any NodeCellConfiguration {
        return NodeCellSimpleConfiguration(from: node, disabled: false, loader: model, featureFlagsController: featureFlagsController)
    }

    func applyAction(completion: @escaping ApplyActionCompletion) {
        completion()
    }
}

extension ComputerRootFolderViewModel: CancellableStoring { }
extension ComputerRootFolderViewModel: LayoutChangingViewModel { }
