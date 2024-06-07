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
import ProtonCoreNetworking
import PDUIComponents

final class TrashViewModel: ObservableObject, FinderViewModel, SortingViewModel, HasMultipleSelection {
    typealias Identifier = NodeIdentifier
    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()

    // MARK: FinderViewModel
    let model: TrashModel
    var childrenCancellable: AnyCancellable?
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []  {
        didSet { selection.updateSelectable(Set(permanentChildren.map(\.node.identifier))) }
    }
    var isVisible: Bool = true
    let genericErrors = ErrorRegulator()
    @Published var isUpdating = false
    
    var nodeName: String {
        listState == .selecting ? "\(selection.selected.count) selected" : "Trash"
    }
    
    var leadingNavBarItems: [NavigationBarButton] {
        listState == .selecting ? [.apply(title: selection.selectAllText, disabled: permanentChildren.isEmpty)] : [.menu]
    }

    var trailingNavBarItems: [NavigationBarButton] {
        listState == .selecting ? [.cancel] : [.action]
    }
    
    let lastUpdated: Date = .distantFuture // not relevant
    let supportsSortingSwitch: Bool = true
    var permanentChildrenSectionTitle: String { self.sorting.title }
    
    let supportsLayoutSwitch = true
    
    func refreshOnAppear() {
        model.loadFromCache()
        fetchAllPages()
    }

    func didScrollToBottom() { }
    
    // MARK: SortingViewModel
    @Published var sorting: SortPreference
    
    func onSortingChanged() {
        /* nothing, as this screen does not support per-page fetching */
    }
    // MARK: HasMultipleSelection
    lazy var selection = MultipleSelectionModel(selectable: Set<NodeIdentifier>())
    @Published var listState: ListState = .active

    @Published var loading = false

    private var deleteRequest: AnyCancellable?

    init(model: TrashModel) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        
        self.layout = Layout(preference: model.layout)
        
        self.subscribeToSort()
        self.subscribeToChildren()
        self.selection.unselectOnEmpty(for: self)
        self.subscribeToLayoutChanges()

    }
    
    func subscribeToSort() {
        self.model.sortingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sort in
                guard let self = self, self.sorting != sort else { return }
                self.sorting = sort
                if self.isVisible {
                    self.onSortingChanged()
                }
            }
            .store(in: &cancellables)
    }
    
    func subscribeToChildren() {
        self.childrenCancellable?.cancel()
        self.childrenCancellable = self.model.childrenTrash()
            .filter { [weak self] _ in
                self?.isVisible == true
            }
            .sink { [weak self] trash in
                guard let self = self, self.isVisible else { return }
                self.permanentChildren = trash.map(NodeWrapper.init)
            }
    }
    
    func subscribeToLayoutChanges() { }
    func changeLayout() { }

    var isSelecting: Bool {
        listState == .selecting
    }

    var activelySelecting: Bool {
        isSelecting && !selection.selected.isEmpty
    }

    func selectAll() {
        selection.updateSelection(with: .all)
        listState = .selecting
    }

    func cancelSelection() {
        listState = .active
        selection.clearSelected()
    }

    func restore(nodes: [NodeIdentifier], completion: @escaping () -> Void) {
        loading = true
        model.restoreFromTrash(nodes: nodes)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.loading = false
                    switch result {
                    case .finished:
                        completion()
                    case .failure(let error):
                        completion()
                        let error: Error = (error as? ResponseError)?.underlyingError ?? error
                        self?.genericErrors.send(error)
                    }
                },
                receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func delete(nodes: [NodeIdentifier], completion: @escaping () -> Void) {
        loading = true
        model.delete(nodes: nodes)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.loading = false
                switch result {
                case .finished: completion()
                case .failure(let error):
                    completion()
                    let error: Error = (error as? ResponseError)?.underlyingError ?? error
                    self?.genericErrors.send(error)
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func emptyTrash(nodes: [NodeIdentifier], completion: @escaping () -> Void) {
        loading = true
        model.emptyTrash(nodes: nodes)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.loading = false
                    switch result {
                    case .finished:
                        completion()
                    case .failure(let error):
                        self?.genericErrors.send(error)
                    }
                },
                receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func findNodesType(isAll: Bool) -> NodeType? {
        let ids = isAll ? selection.selectable : selection.selected
        let selectedIds = permanentChildren.filter { nodeId in
            ids.contains(nodeId.node.identifier)
        }
        let selectedTypes = Set(selectedIds.map { ($0.node is Folder) ? NodeType.folder : .file })
        if selectedTypes.isSuperset(of: [.file, .folder]) {
            return .mix
        } else if selectedTypes.count == 1 {
            return selectedTypes.first
        } else {
            return nil
        }
    }
}

extension TrashViewModel {
    func fetchAllPages() {
        guard !isUpdating else { return }
        isUpdating = true

        Task {
            do {
                try await model.fetchTrash()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isUpdating = false
                }
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let error: Error = (error as? ResponseError)?.underlyingError ?? error
                    self.genericErrors.send(error)
                    self.isUpdating = false
                }
            }
        }
    }

    func actionBarItems() -> [ActionBarButtonViewModel] {
        [.restoreMultiple, .deleteMultiple]
    }
}

extension TrashViewModel {
    func selected(file: File) { }
    func childViewModel(for node: Node) -> NodeCellConfiguration { fatalError() }
    func applyAction(completion: @escaping ApplyActionCompletion) { }
}

extension TrashViewModel: CancellableStoring { }
extension TrashViewModel: LayoutChangingViewModel { }

extension TrashModel: LayoutChanging {
    public var layout: LayoutPreference {
        .list
    }

    public var layoutPublisher: AnyPublisher<LayoutPreference, Never> {
        tower.layoutPublisher
    }

    public func changeLayoutPreference(to newLayout: LayoutPreference) {
        tower.changeLayoutPreference(to: newLayout)
    }
}
