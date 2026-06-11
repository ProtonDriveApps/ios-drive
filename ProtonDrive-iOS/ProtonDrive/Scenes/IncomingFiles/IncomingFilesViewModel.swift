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
import Foundation
import PDCore
import PDCoreIOS
import PDLocalization
import PDUIComponents
import ProtonCoreNetworking

final class IncomingFilesViewModel:
    ObservableObject,
    FinderViewModel,
    HasRefreshControl,
    FetchingViewModel,
    SortingViewModel {

    @Published var lastUpdated = Date.distantPast
    @Published var layout: Layout
    @Published var permanentChildren: [NodeWrapper] = []
    @Published var transientChildren: [NodeWrapper] = []
    @Published var sorting: SortPreference
    @Published var isUpdating = false
    let animationDuration: DispatchTimeInterval = .seconds(3)
    let featureFlagsController: FeatureFlagsControllerProtocol
    let genericErrors = ErrorRegulator()
    let hasPlusFunctionality = false
    let isRoot: Bool = false
    let isSharedWithMe = false
    let model: IncomingFilesModel
    private let onSaveHere: ((Folder) -> Void)?
    let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>? = nil

    var cancellables = Set<AnyCancellable>()
    var childrenCancellable: AnyCancellable?
    var currentTab: TabBarItem?
    var fetchFromAPICancellable: AnyCancellable?
    var isVisible: Bool = true // otherwise changes in onAppear will break deeplinking
    var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    var lockedStateCancellable: AnyCancellable?
    var permanentChildrenSectionTitle = ""
    var supportsLayoutSwitch: Bool { false }
    var supportsSortingSwitch: Bool { false }

    var nodeName: String {
        guard let node = node else {
            return NodeCellWithProgressConfiguration.unknownNamePlaceholder
        }
        return node.isRoot ? Localization.menu_text_my_files : node.decryptedName
    }
    lazy var leadingNavBarItems: [NavigationBarButton] = [.apply(title: "", disabled: true)]
    lazy var trailingNavBarItems: [NavigationBarButton] = [
        .apply(title: Localization.share_action_save_here, disabled: false)
    ]

    func reportListIsShown() {}

    init(
        model: IncomingFilesModel,
        node: Folder,
        onSaveHere: ((Folder) -> Void)? = nil,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.onSaveHere = onSaveHere
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        self.featureFlagsController = featureFlagsController

        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToLayoutChanges()
    }

    func refreshOnAppear() {
        self.model.loadFromCache()
        self.fetchPages()
    }

    func didScrollToBottom() {
        if self.refreshMode == .fetchPageByRequest {
            self.fetchNextPageFromAPI()
        }
    }

    func selected(file: File) { }

    func childViewModel(for node: Node) -> NodeCellConfiguration {
        let shouldDisable = node is File
        return NodeCellSimpleConfiguration(from: node, disabled: shouldDisable, loader: model, featureFlagsController: featureFlagsController)
    }

    func applyAction(completion: @escaping ApplyActionCompletion) {
        if let onSaveHere, let currentFolder = model.folder {
            onSaveHere(currentFolder)
            completion()
        }
    }
}

extension IncomingFilesViewModel: CancellableStoring { }

extension IncomingFilesViewModel: LayoutChangingViewModel { }
