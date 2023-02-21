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
import PDUIComponents

final class OfflineAvailableViewModel: ObservableObject, FinderViewModel, DownloadingViewModel, HasMultipleSelection {

    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()

    // MARK: FinderViewModel
    let model: OfflineAvailableModel
    let sorting: SortPreference
    func subscribeToSort() { }
    var childrenCancellable: AnyCancellable?
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = [] {
        didSet { selection.updateSelectable(Set(permanentChildren.map(\.id))) }
    }
    @Published var isVisible: Bool = true
    let genericErrors = ErrorRegulator()

    @Published var isUpdating: Bool = false
    
    var nodeName: String {
        self.listState.isSelecting ? self.titleDuringSelection() : "Available offline"
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
    lazy var selection = MultipleSelectionModel(selectable: Set<String>())
    @Published var listState: ListState = .active
    
    // MARK: others
    init(model: OfflineAvailableModel) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)

        self.subscribeToChildren()
        self.subscribeToChildrenDownloading()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()
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
