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
import PDUIComponents

final class TrashViewModel: ObservableObject, HasMultipleSelection {

    var trashModel: TrashModelProtocol
    let selection: MultipleSelectionModel

    @Published var loading = false
    @Published var isUpdating = false
    @Published var listState: ListState = .active
    @Published private(set) var trashedNodes: [Node] = []

    let genericErrors = ErrorRegulator()
    private var deleteRequest: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(model: TrashModelProtocol, selection: MultipleSelectionModel) {
        self.trashModel = model
        self.selection = selection
        model.trashItems
            .sink(receiveValue: { [weak self] trashed in
                guard let self = self else { return }
                self.trashedNodes = trashed
                self.selection.updateSelectable(Set(trashed.map(\.id)))
            })
            .store(in: &cancellables)
    }

    // Settable properties required by FinderViewModel
    var childrenCancellable: AnyCancellable?
    var transientChildren: [NodeWrapper] = []
    var permanentChildren: [NodeWrapper] = []
    var isVisible: Bool = true
}

extension TrashViewModel {
    var isSelecting: Bool {
        listState == .selecting
    }

    var activelySelecting: Bool {
        isSelecting && !selection.selected.isEmpty
    }

    var pageTitle: String {
        listState == .selecting ? "\(selection.selected.count) selected" : "Trash"
    }

    var leadingNavBarItems: [NavigationBarButton] {
        listState == .selecting ? [.apply(title: selection.selectAllText, disabled: trashedNodes.isEmpty)] : [.menu]
    }

    var trailingNavBarItems: [NavigationBarButton] {
        listState == .selecting ? [.cancel] : [.action]
    }

    func onAppear() {
        // TODO: DRVIOS-1278 - here we can use `trashModel.didFetchAllTrash` to fetch all pages only once and get updates from event system
        fetchTrash()
    }

    func onRefresh() {
        fetchTrash()
    }

    func selectAll() {
        selection.updateSelection(with: .all)
        listState = .selecting
    }

    func cancelSelection() {
        listState = .active
        selection.clearSelected()
    }

    func restore(nodes: [String], completion: @escaping () -> Void) {
        loading = true
        trashModel.restoreFromTrash(nodes: nodes)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.loading = false
                    switch result {
                    case .finished:
                        completion()
                    case .failure(let error):
                        completion()
                        self?.genericErrors.send(error)
                    }
                },
                receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func delete(nodes: [String], completion: @escaping () -> Void) {
        loading = true
        trashModel.delete(nodes: nodes)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.loading = false
                switch result {
                case .finished: completion()
                case .failure(let error):
                    completion()
                    self?.genericErrors.send(error)
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func emptyTrash(nodes: [String], completion: @escaping () -> Void) {
        loading = true
        trashModel.emptyTrash(nodes: nodes)
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
        let pool = Dictionary(uniqueKeysWithValues: trashedNodes.map { ($0.id, $0 is Folder) })
        let ids = isAll ? selection.selectable : selection.selected
        let types = Set(ids.compactMap { pool[$0] })
        let folder = true
        if types.count == 2 {
            return .mix
        } else if types.count == 1  {
            return types.first == folder ? .folder : .file
        } else {
            return nil
        }
    }

    func refreshControlAction() {
        fetchTrash()
    }
}

extension TrashViewModel {
    private func fetchTrash() {
        guard !isUpdating else { return }
        isUpdating = true

        trashModel.fetchTrash(at: 0) { [weak self] result in
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

class FakeTrashModel: FinderModel, NodesListing, ThumbnailLoader {
    var folder: Folder?
    func loadFromCache() {}
    var tower: Tower!
    var childrenObserver: FetchedObjectsObserver<Node>  { fatalError() }
    var sorting: SortPreference { fatalError() }
    func loadThumbnail(with file: Identifier) { }
    func cancelThumbnailLoading(_ id: ThumbnailLoader.Identifier) { }
}

extension TrashViewModel: FinderViewModel {
    var model: FakeTrashModel { fatalError() }
    var sorting: SortPreference { .modifiedAscending }
    var supportsSortingSwitch: Bool { false }
    var permanentChildrenSectionTitle: String { "" }
    func subscribeToSort() {}
    var layout: Layout { .list }
    var supportsLayoutSwitch: Bool { false }
    func changeLayout() {}
    var nodeName: String { "" }
    var lastUpdated: Date { Date() }
    func refreshOnAppear() { }
    func didScrollToBottom() { }
    func selected(file: File) { }
    func childViewModel(for node: Node) -> NodeCellConfiguration { fatalError() }
    func applyAction(completion: @escaping ApplyActionCompletion) { }
}
