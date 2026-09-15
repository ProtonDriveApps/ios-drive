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
import SwiftUI
import PDUIComponents
import PDLocalization

class FolderViewModel: ObservableObject, FinderViewModel, FetchingViewModel, HasRefreshControl, UploadingViewModel, DownloadingViewModel, SortingViewModel, HasMultipleSelection {
    typealias FolderErrorModel = FolderModel & FinderErrorModel
    typealias Identifier = NodeIdentifier
    private let localSettings: LocalSettings
    private let volumeIdsController: SharedVolumeIdsController
    private let upgradeRequirementBannerController: UpgradeRequirementBannerControllerProtocol
    var upgradeRequirementHandling: UpgradeRequirementHandling? { upgradeRequirementBannerController }
    let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?
    let currentTab: TabBarItem?

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

    var isSharedWithMe: Bool
    let hasPlusFunctionality: Bool

    let uploadErrors = ErrorRegulator()
    let genericErrors = ErrorRegulator()

    var nodeName: String {
        guard !self.listState.isSelecting else {
            return self.titleDuringSelection()
        }
        guard let node = node else {
            return NodeCellWithProgressConfiguration.unknownNamePlaceholder
        }
        return node.isRoot ? Localization.menu_text_my_files : node.decryptedName
    }

    var isRoot: Bool { node?.isRoot ?? false }

    @Published var isUpdating = false

    var trailingNavBarItems: [NavigationBarButton] {
        if listState.isSelecting {
            return [.cancel]
        } else {
            var items: [NavigationBarButton] = [.upload]
            if isRoot, !isPaidUser {
                items.insert(.subscribe, at: 0)
            }
            return items
        }
    }

    var leadingNavBarItems: [NavigationBarButton] {
        if self.listState.isSelecting {
            return [.apply(title: selection.selectAllText, disabled: false)]
        } else if isSharedWithMe {
            return [.apply(title: "", disabled: true)]
        } else if self.node?.isRoot == true {
            return [.menu]
        } else {
            return []
        }
    }

    var supportsSortingSwitch: Bool = true
    var permanentChildrenSectionTitle: String { self.sorting.title }

    let supportsLayoutSwitch = true
    let featureFlagsController: FeatureFlagsControllerProtocol

    @Published var isUploadDisclaimerVisible: Bool = false
    @Published var upgradeRequirementLevel: UpgradeRequirementLevel = .none

    func closeUploadDisclaimer() {
        localSettings.isUploadingDisclaimerActive = false
    }

    // MARK: FetchingViewModel
    @Published var lastUpdated = Date.distantPast
    var fetchFromAPICancellable: AnyCancellable?

    // MARK: UploadingViewModel
    var childrenUploadCancellable: AnyCancellable?
    let showsUploadsErrorBanner: Bool = true
    @Published var hasReceivedUploadsUpdate: Bool = false
    var failedCount: Int {
        return transientChildren.map(\.node).filter(isUploadFailed).count
    }
    let nodeStatePolicy: NodeStatePolicy

    // MARK: DownloadingViewModel
    var childrenDownloadCancellable: AnyCancellable?

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
    private var multiselectWasActivatedOnce: Bool = false
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active

    // MARK: others
    var isPaidUser = false
    let progressTrackersController: ProgressTrackersControllerProtocol

    lazy var nodeDownloadedResource: NodeDownloadedResource = {
        NodeDownloadedResource(managedObjectContext: model.tower.storage.newBackgroundContext())
    }()

    init(
        localSettings: LocalSettings,
        model: FolderErrorModel,
        node: Folder,
        nodeStatePolicy: NodeStatePolicy,
        featureFlagsController: FeatureFlagsControllerProtocol,
        isSharedWithMe: Bool = false,
        volumeIdsController: SharedVolumeIdsController,
        scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?,
        progressTrackersController: ProgressTrackersControllerProtocol
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
        self.currentTab = isSharedWithMe ? .sharedWithMe : .files
        hasPlusFunctionality = !isSharedWithMe || node.getNodePermissions() != .view
        self.progressTrackersController = progressTrackersController
        self.upgradeRequirementBannerController = UpgradeRequirementBannerController(
            appStorePageURL: Constants.appStorePageURL,
            localSettings: localSettings
        )

        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToChildrenUploading()
        self.subscribeToChildrenDownloading()
        self.subscribeToSDKNotify()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()
        self.subscribeToUserInfoUpdates()
        setupLockedStateBannerVisibility()
        subscribeLocalSettings()

        if let controller = model.userInfoController {
            controller.userInfo
                .removeDuplicates()
                .sink { [weak self] info in
                    guard let info else { return }
                    self?.isPaidUser = info.isPaid
                }
                .store(in: &cancellables)
        }

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
                    self?.multiselectWasActivatedOnce = true
                }
            }
            .store(in: &cancellables)

        model.errorSubject
            .sink { [weak self] error in
                self?.genericErrors.stream.send(error)
            }
            .store(in: &cancellables)
    }

    private func subscribeLocalSettings() {
        localSettings.publisher(for: \.isUploadingDisclaimerActive)
            .sink { [weak self] value in
                self?.isUploadDisclaimerVisible = value
            }
            .store(in: &cancellables)

        upgradeRequirementBannerController
            .subscribeToUpgradeRequirement(currentTab: currentTab)
            .sink { [weak self] level in
                self?.upgradeRequirementLevel = level
            }
            .store(in: &cancellables)
    }

    func actionBarItems() -> [ActionBarButtonViewModel] {
        let isOfflineAvailablePossible = selectedNodes().contains(where: { $0.node.isDownloadable })
        guard let node else {
            return []
        }

        switch node.getNodePermissions() {
        case .administrate, .edit:
            return [
                .trashMultiple,
                .moveMultiple,
                isOfflineAvailablePossible ? .offlineAvailableMultiple : nil
            ].compactMap { $0 }
        case .view:
            return [
                isOfflineAvailablePossible ? .offlineAvailableMultiple : nil
            ].compactMap { $0 }
        }
    }

    func reportListIsShown() {
        model.tower.performanceMetricsController?.reportTabToFirstItem(pageType: .myFiles)
    }
}

extension MultipleSelectionModel {
    var selectAllText: String {
        selected == selectable ? Localization.general_deselect_all : Localization.general_select_all
    }
}

extension FolderViewModel: CancellableStoring { }
extension FolderViewModel: LayoutChangingViewModel { }

extension FolderModel: LayoutChanging {
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
