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
import PDUIComponents

class FolderViewModel: ObservableObject, FinderViewModel, FetchingViewModel, HasRefreshControl, UploadingViewModel, DownloadingViewModel, SortingViewModel, HasMultipleSelection {
    typealias FolderErrorModel = FolderModel & FinderErrorModel
    private let localSettings: LocalSettings
    
    // MARK: FinderViewModel
    let model: FolderModel
    var cancellables = Set<AnyCancellable>()
    var childrenCancellable: AnyCancellable?
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []

    @Published var layout: Layout

    var isVisible: Bool = true

    let uploadErrors = ErrorRegulator()
    let genericErrors = ErrorRegulator()
    
    var nodeName: String {
        guard !self.listState.isSelecting else {
            return self.titleDuringSelection()
        }
        guard let node = node else {
            return NodeCellWithProgressConfiguration.unknownNamePlaceholder
        }
        return node.isRoot ? "My files" : node.decryptedName
    }
    
    @Published var isUpdating = false
    
    var trailingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.cancel] : [.upload]
    }
    
    var leadingNavBarItems: [NavigationBarButton] {
        if self.listState.isSelecting {
            return [.apply(title: selection.selectAllText, disabled: false)]
        } else if self.node?.isRoot == true {
            return [.menu]
        } else {
            return [.apply(title: "", disabled: true)]
        }
    }
    
    var supportsSortingSwitch: Bool = true
    var permanentChildrenSectionTitle: String { self.sorting.title }

    let supportsLayoutSwitch = true
    
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
    @Published var uploadsCount: (active: Int, total: Int) = (0, 0)
    @Published var uploadProgresses: [UUID: Progress] = [:]
    
    // MARK: DownloadingViewModel
    var childrenDownloadCancellable: AnyCancellable?
    @Published var downloadProgresses: [ProgressTracker] = []
    
    // MARK: SortingViewModel
    @Published var sorting: SortPreference

    func refreshOnAppear() {
        self.layout = .init(preference: self.model.layout)
        self.model.loadFromCache()
        self.fetchPages()
    }
    
    func didScrollToBottom() {
        if self.refreshMode == .fetchPageByRequest {
            self.fetchNextPageFromAPI()
        }
    }
    
    // MARK: HasMultipleSelection
    private var multiselectWasActivatedOnce: Bool = false
    lazy var selection = MultipleSelectionModel(selectable: Set<String>())
    @Published var listState: ListState = .active
    
    // MARK: others
    init(localSettings: LocalSettings, model: FolderErrorModel, node: Folder) {
        self.localSettings = localSettings
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        
        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToChildrenUploading()
        self.subscribeToChildrenDownloading()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()
        setupUploadBannerVisibility()

        $permanentChildren
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] permanent in
                self?.selection.updateSelectable(Set(permanent.map(\.id)))
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
    
    private func setupUploadBannerVisibility() {
        localSettings.publisher(for: \.isUploadingDisclaimerActive)
            .sink { [weak self] value in
                self?.isUploadDisclaimerVisible = value
            }
            .store(in: &cancellables)
    }
}

extension MultipleSelectionModel {
    var selectAllText: String {
        selected == selectable ? "Deselect all" : "Select all  "
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
