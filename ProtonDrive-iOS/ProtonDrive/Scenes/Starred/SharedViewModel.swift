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

class SharedViewModel: ObservableObject, FinderViewModel, DownloadingViewModel, SortingViewModel, HasMultipleSelection, HasRefreshControl {

    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()

    // MARK: FinderViewModel
    let model: SharedModel
    var childrenCancellable: AnyCancellable?
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []  {
        didSet { selection.updateSelectable(Set(permanentChildren.map(\.id))) }
    }
    var isVisible: Bool = true
    let genericErrors = ErrorRegulator()
    @Published var isUpdating: Bool = false
    
    var nodeName: String {
        self.listState.isSelecting ? self.titleDuringSelection() : "Shared"
    }
    
    var trailingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.cancel] : [.apply(title: "", disabled: true)]
    }
    
    var leadingNavBarItems: [NavigationBarButton] {
        self.listState.isSelecting ? [.apply(title: selection.selectAllText, disabled: false)] : [.menu]
    }
    
    let lastUpdated: Date = .distantFuture // not relevant
    let supportsSortingSwitch: Bool = true
    var permanentChildrenSectionTitle: String { self.sorting.title }

    let supportsLayoutSwitch = true
    
    func refreshControlAction() {
        fetchAllPages()
    }
    
    func refreshOnAppear() {
        model.loadFromCache()
        if !model.tower.didFetchAllShareURLs {
            fetchAllPages()
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
    lazy var selection = MultipleSelectionModel(selectable: Set<String>())
    @Published var listState: ListState = .active
    
    // MARK: others
    init(model: SharedModel) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        
        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToChildrenDownloading()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()
    }
}

extension SharedViewModel {
    private func fetchAllPages() {
        guard !isUpdating else { return }
        self.isUpdating = true

        model.fetchShared(at: 0) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isUpdating = false

                case .failure(let error):
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.genericErrors.send(error)
                        self.isUpdating = false
                    }
                }
            }
        }
    }
}

extension MultipleSelectionModel {
    func unselectOnEmpty(for vm: HasMultipleSelection) {
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
