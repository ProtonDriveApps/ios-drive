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

class MoveViewModel: ObservableObject, FinderViewModel, HasRefreshControl, FetchingViewModel, SortingViewModel {

    @Published var layout: Layout
    var cancellables = Set<AnyCancellable>()

    // MARK: FinderViewModel
    let model: MoveModel
    var childrenCancellable: AnyCancellable?
    var lockedStateCancellable: AnyCancellable?
    var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    @Published var transientChildren: [NodeWrapper] = []
    @Published var permanentChildren: [NodeWrapper] = []
    let animationDuration: DispatchTimeInterval = .seconds(3)
    var isVisible: Bool = true // otherwise changes in onAppear will break deeplinking
    let genericErrors = ErrorRegulator()
    
    var nodeName: String {
        guard let node = node else {
            return NodeCellWithProgressConfiguration.unknownNamePlaceholder
        }
        return node.isRoot ? "My files" : node.decryptedName
    }
    
    lazy var trailingNavBarItems: [NavigationBarButton] = [
        .apply(title: "Move here", disabled: self.model.node.identifier.nodeID == self.model.nodeToMoveParentId.nodeID)
    ]
    
    lazy var leadingNavBarItems: [NavigationBarButton] = [.apply(title: "", disabled: true)]
    @Published var lastUpdated = Date.distantPast
    var supportsSortingSwitch: Bool { false }
    var permanentChildrenSectionTitle = ""

    var supportsLayoutSwitch: Bool { false }
    
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
        let shouldDisable = node is File || self.model.nodeIdsToMove.contains(node.identifier)
        return NodeCellSimpleConfiguration(from: node, disabled: shouldDisable, loader: model)
    }
    
    func applyAction(completion: @escaping () -> Void) {
        self.isUpdating = true
        self.model.moveHere { result in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                switch result {
                case let .failure(error):
                    let error: Error = (error as? ResponseError)?.underlyingError ?? error
                    self.genericErrors.send(error)
                case .success:
                    completion()
                }
            }
        }
    }
    
    // MARK: FetchingViewModel
    @Published var isUpdating = false
    var fetchFromAPICancellable: AnyCancellable?
    
    // MARK: SortingViewModel
    @Published var sorting: SortPreference

    // MARK: others
    init(model: MoveModel, node: Folder) {
        defer { self.model.loadFromCache() }
        self.model = model
        self.sorting = model.sorting
        self.layout = Layout(preference: model.layout)
        
        self.subscribeToSort()
        self.subscribeToChildren()
        self.subscribeToLayoutChanges()
    }
}

extension MoveViewModel: CancellableStoring { }
extension MoveViewModel: LayoutChangingViewModel { }

extension MoveModel: LayoutChanging {
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
