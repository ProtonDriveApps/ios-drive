// Copyright (c) 2026 Proton AG
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
import PDSDKCore
import PDLocalization
import PDUIComponents

/// Scene specific UI / business logic
@MainActor
protocol FinderPresenting: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var currentTab: TabBarItem? { get }
    var hasModalActionBar: Bool { get }
    var leadingNavBarItems: [NavigationBarButton] { get }
    var modalLeadingActionItems: [ActionBarButtonViewModel] { get }
    var modalTrailingActionItems: [ActionBarButtonViewModel] { get }
    var navigationTitle: String { get }
    var shouldReportPerformance: Bool { get }
    var supportsLayoutSwitch: Bool { get }
    var supportsMultipleSelection: Bool { get }
    var supportsSortingSwitch: Bool { get }
    var trailingNavBarItems: [NavigationBarButton] { get }
    var isUploadDisclaimerVisible: Bool { get }

    func bottomActionItems(selected: [NodeDTO]) -> [ActionBarButtonViewModel]
    func startRecordingPerformance(id: AnyVolumeIdentifier)
    func makeCellViewModel(for node: NodeDTO) -> FFinderCellViewModel
    func applyAction() async throws
}

@MainActor
final class FolderFinderScene: FinderPresenting {
    @Published private var isPaidUser = false
    @Published private(set) var isUploadDisclaimerVisible: Bool = false

    let currentTab: TabBarItem? = .files
    let hasModalActionBar: Bool = false
    let modalLeadingActionItems: [ActionBarButtonViewModel] = []
    let modalTrailingActionItems: [ActionBarButtonViewModel] = []
    let shouldReportPerformance: Bool = true
    let supportsLayoutSwitch: Bool = true
    let supportsMultipleSelection: Bool = true
    let supportsSortingSwitch: Bool = true

    private let dependencies: Dependencies
    private let folder: NodeDTO
    private var cancellables = Set<AnyCancellable>()
    private var isSelecting: Bool { dependencies.multipleSelectionModel.isSelectionEnabled }

    init(dependencies: Dependencies, folder: NodeDTO) {
        self.dependencies = dependencies
        self.folder = folder
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        dependencies.userInfoController.userInfo
            .sink { [weak self] info in
                guard let self, let info else { return }
                self.isPaidUser = info.isPaid
            }
            .store(in: &cancellables)

        dependencies.localSettings.publisher(for: \.isUploadingDisclaimerActive)
            .sink { [weak self] value in
                self?.isUploadDisclaimerVisible = value
            }
            .store(in: &cancellables)
    }

    func applyAction() async throws  {}
}

// MARK: - Navigation bar present
extension FolderFinderScene {
    var navigationTitle: String {
        if isSelecting {
            return Localization.general_selected(num: dependencies.multipleSelectionModel.selected.count)
        }
        return folder.isRoot ? Localization.menu_text_my_files : folder.name
    }

    var trailingNavBarItems: [NavigationBarButton] {
        if isSelecting {
            return [.cancel]
        } else {
            var items: [NavigationBarButton] = [.upload]
            if folder.isRoot, !isPaidUser {
                items.insert(.subscribe, at: 0)
            }
            return items
        }
    }

    var leadingNavBarItems: [NavigationBarButton] {
        if isSelecting {
            return [.toggleSelectAll(title: dependencies.multipleSelectionModel.selectAllText)]
        } else if folder.isRoot {
            return [.menu]
        } else {
            return []
        }
    }
}

// MARK: - Bottom action bar present
extension FolderFinderScene {
    func bottomActionItems(selected: [NodeDTO]) -> [ActionBarButtonViewModel] {
        let isOfflineAvailablePossible = selected.contains(where: { $0.isDownloadable })
        let hasExportableFile = selected.contains(where: { $0.canExport })
        let isDownloadPossible = dependencies.featureFlagsController.hasUnlimitedDownloads
            && hasExportableFile
            && selected.count > 1

        switch folder.permissions {
        case .administrate, .edit:
            return [
                .trashMultiple,
                .moveMultiple,
                isOfflineAvailablePossible ? .offlineAvailableMultiple : nil,
                isDownloadPossible ? .downloadMultiple : nil
            ].compactMap { $0 }
        case .view:
            return [
                isOfflineAvailablePossible ? .offlineAvailableMultiple : nil,
                isDownloadPossible ? .downloadMultiple : nil
            ].compactMap { $0 }
        }
    }
}

// MARK: - Cell
extension FolderFinderScene {
    func makeCellViewModel(for node: NodeDTO) -> FFinderCellViewModel {
        let isActive = node.state == .active
        return dependencies.viewModelFactory.makeCellViewModel(
            parameters: .init(
                actionHandler: dependencies.actionHandler,
                isSharedWithMeRoot: folder.isSharedWithMeRoot,
                node: node,
                selectionModel: dependencies.multipleSelectionModel,
                shouldDisable: false,
                supportSelection: isActive
            )
        )
    }
}

// MARK: - Performance
extension FolderFinderScene {
    func startRecordingPerformance(id: AnyVolumeIdentifier) {
        dependencies.performanceMetricsController?.startRecord(id: id, pageType: .myFiles)
    }
}

extension FolderFinderScene {
    struct Dependencies {
        let actionHandler: FinderActionHandling
        let featureFlagsController: FeatureFlagsControllerProtocol
        let localSettings: LocalSettings
        let multipleSelectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>
        let performanceMetricsController: PerformanceMetricsControllerProtocol?
        let userInfoController: UserInfoController
        let viewModelFactory: FinderViewModelFactory
    }
}
