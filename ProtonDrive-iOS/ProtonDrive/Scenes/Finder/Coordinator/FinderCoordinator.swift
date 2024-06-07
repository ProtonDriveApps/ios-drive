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
import SwiftUI
import UIKit
import PDCore
import PDUIComponents

class FinderCoordinator: NSObject, ObservableObject, SwiftUICoordinator {
    enum Context {
        case move(rootNode: NodeIdentifier, nodesToMove: [NodeIdentifier], nodeToMoveParent: NodeIdentifier)
        case folder(nodeID: NodeIdentifier)
        case shared
        case offlineAvailable
    }
    
    private let tower: Tower
    private let deeplink: Deeplink?
    private let photoPickerCoordinator: PhotosPickerCoordinator?
    private(set) var onDisappear: () -> Void = { }
    private(set) var onAppear: () -> Void = { }
    private(set) var model: FinderModel? // Previously we had it weak but iOS 14 was mysteriously nullifying it after some Move manipulations - see DRVIOS-581
    private(set) weak var previousFolderCoordinator: FinderCoordinator?
    private(set) weak var nextFolderCoordinator: FinderCoordinator?
    
    // Binding observed by FinderView's NavigationView
    @Published private var _drilldownTo: Node.ID?
    lazy var drilldownTo: Binding<Node.ID?> = .init { [weak self] in
        self?._drilldownTo
    } set: { [weak self] in
        self?._drilldownTo = $0
    }
    
    // Binding observed by FinderView's fullscreen modal presenter
    @Published private var _presentedModal: Destination?
    lazy var presentModal: Binding<Destination?> = .init {  [weak self] in
        self?._presentedModal
    } set: {  [weak self] in
        self?._presentedModal = $0
    }

    init(tower: Tower, parent: FinderCoordinator? = nil, deeplink: Deeplink? = nil, photoPickerCoordinator: PhotosPickerCoordinator? = nil) {
        self.tower = tower
        self.deeplink = deeplink
        self.previousFolderCoordinator = parent
        self.photoPickerCoordinator = photoPickerCoordinator
    }
}

// MARK: - start(_:)

extension FinderCoordinator {
    func start(_ context: Context) -> some View {
        defer { self.deeplink(from: deeplink, tower: tower) }
        return self.startView(context)
    }
     
    @ViewBuilder
    private func startView(_ context: Context) -> some View {
        switch context {
        case let .move(nodeID, nodesToMoveID, nodeToMoveParent):
            if let node = tower.uiSlot?.subscribeToNode(nodeID) as? Folder {
                self.startMove(nodeID, nodesToMoveID, nodeToMoveParent, node)
            } else {
                TechnicalErrorPlaceholderView(message: "Start Move with insufficient context")
            }
            
        case let .folder(nodeID):
            if let node = tower.uiSlot?.subscribeToNode(nodeID) as? Folder {
                self.startFolder(nodeID, node)
            } else {
                TechnicalErrorPlaceholderView(message: "Start Folder with insufficient context")
            }
            
        case .offlineAvailable:
            self.startOfflineAvailable()

        case let .shared:
            if let volume = tower.uiSlot.getVolume() {
                self.startShared(volumeID: volume.id)
            } else {
                TechnicalErrorPlaceholderView(message: "Started Shared Folder with insufficient context")
            }
        }
    }
    
    private func startMove(_ nodeID: NodeIdentifier, _ nodesToMoveID: [NodeIdentifier], _ nodeToMoveParent: NodeIdentifier, _ node: Folder) -> some View {
        let model = MoveModel(tower: tower, node: node, nodeID: nodeID, nodesToMoveID: nodesToMoveID, nodeToMoveParentID: nodeToMoveParent)
        self.model = model
        let viewModel = MoveViewModel(model: model, node: node)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }
    
    private func startOfflineAvailable() -> some View {
        let model = OfflineAvailableModel(tower: tower)
        self.model = model
        let viewModel = OfflineAvailableViewModel(model: model)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }
    
    private func startShared(volumeID: String) -> some View {
        let model = SharedModel(tower: tower, volumeID: volumeID)
        self.model = model
        let viewModel = SharedViewModel(model: model)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }
    
    private func startFolder(_ nodeID: NodeIdentifier, _ node: Folder) -> some View {
        let model = FolderModel(tower: tower, node: node, nodeID: nodeID)
        self.model = model
        let viewModel = FolderViewModel(localSettings: tower.localSettings, model: model, node: node, nodeStatePolicy: FileNodeStatePolicy())
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }
    
}

// MARK: - go(to:)

extension FinderCoordinator {
    @ViewBuilder
    func go(to destination: Destination) -> some View {
        switch destination {
        case let .folder(folder) where model is MoveModel:
            self.goFolderMove(folder, model as! MoveModel)

        case let .folder(folder):
            self.goFolder(folder)

        case let .move(nodes, parent):
            if let firstNode = nodes.first, let rootId = firstNode.parentsChain().first?.identifier, let parentId = parent?.identifier {
                self.goMove(firstNode, nodes, rootId, parentId)
            } else {
                TechnicalErrorPlaceholderView(message: "Called Go-Move with insufficient context")
            }

        case let .file(file, share):
            // this one should not be cached as we do not want to keep cleartext file longer than needed
            FileCoordinator(tower: tower, parent: self).start((file, share))

        case .importDocument where model is PickerDelegate:
            DocumentPicker(delegate: model as! PickerDelegate)
                .edgesIgnoringSafeArea(.all)

        case .importPhoto where model is PickerDelegate:
            photoPickerCoordinator.map { coordinator in
                coordinator.start(with: model as! PickerDelegate)
                    .edgesIgnoringSafeArea(.bottom)
            }

        case .camera where model is PickerDelegate:
            CameraPicker(delegate: model as! PickerDelegate)
                .edgesIgnoringSafeArea(.all)

        case let .nodeDetails(nextNode):
            NodeDetailsCoordinator().start((tower, nextNode))

        case let .createFolder(parent):
            EditNodeCoordinator().start((tower, parent, .create))
                .edgesIgnoringSafeArea(.bottom)

        case let .rename(node) where node.parentLink != nil:
            EditNodeCoordinator().start((tower, node.parentLink!, .rename(node)))
                .edgesIgnoringSafeArea(.bottom)

        case .noSpaceLeftLocally:
            NoSpaceView(storage: .local)

        case .noSpaceLeftCloud:
            NoSpaceView(storage: .cloud)

        case let .shareLink(node: node):
            ShareLinkFlowCoordinator().start((node, tower))

        default: // fallen conditions and .none
            TechnicalErrorPlaceholderView()
        }
    }

    private func goFolderMove(_ folder: Folder, _ model: MoveModel) -> some View {
        let nodesToMoveID = model.nodeIdsToMove
        let nodeToMoveParentID = model.nodeToMoveParentId
        let coordinator = FinderCoordinator(tower: tower, parent: self, deeplink: deeplink)
        nextFolderCoordinator = coordinator
        return coordinator.start(.move(rootNode: folder.identifier, nodesToMove: nodesToMoveID, nodeToMoveParent: nodeToMoveParentID))
    }
    
    private func goFolder(_ folder: Folder) -> some View {
        let coordinator = FinderCoordinator(tower: tower, parent: self, deeplink: deeplink, photoPickerCoordinator: photoPickerCoordinator)
        nextFolderCoordinator = coordinator
        return coordinator.start(.folder(nodeID: folder.identifier))
    }
    
    private func goMove(_ firstNode: Node, _ nodes: [Node], _ rootId: NodeIdentifier, _ parentId: NodeIdentifier) -> some View {
        let nodeIds = nodes.map(\.identifier)
        let coordinator = FinderCoordinator(tower: tower, deeplink: nil) // no connection to parent (current one) as new one is a root of new chain
        return RootMoveView(coordinator: coordinator, nodes: nodeIds, root: rootId, parent: parentId)
    }
    
}

extension FinderCoordinator: UINavigationControllerDelegate {
    var topmostDescendant: FinderCoordinator? {
        descendants.last
    }
    
    private var ancestors: [FinderCoordinator] {
        var chain = [previousFolderCoordinator]
        chain.insert(contentsOf: previousFolderCoordinator?.ancestors ?? [], at: 0)
        return chain.compactMap { $0 }
    }
    
    private var descendants: [FinderCoordinator] {
        var chain = [nextFolderCoordinator]
        chain.append(contentsOf: nextFolderCoordinator?.descendants ?? [])
        return chain.compactMap { $0 }
    }
    
    var fullCoordinatorsChain: [FinderCoordinator] {
        var chain = ancestors
        chain.append(self)
        chain.append(contentsOf: descendants)
        return chain
    }
    
    private func hookIntoViewLifecycle<T: FinderViewModel>(_ viewModel: T) {
        self.onAppear = { [weak viewModel] in
            viewModel?.isVisible = true
            viewModel?.refreshOnAppear()
        }
        self.onDisappear = { [weak viewModel] in
            viewModel?.isVisible = false
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Built-in onAppear() of SwiftUI does not work correctly for NavigationLinks in ScrollView+LazyVGrid.
        // At least on iOS 14.4 calls it wrongly for root FinderView whenever topmost FinderView changes layout or sorting
        let count = navigationController.viewControllers.count
        
        let fullChain = self.fullCoordinatorsChain
        fullChain.dropFirst(count).forEach { $0.onDisappear() } // all descendants of current
        
        let newChain = fullChain.prefix(count)
        newChain.dropLast().forEach { $0.onDisappear() } // all ancestors of current
        
        // On iOS16 this causes runtime warning: `Publishing changes from within view updates is not allowed, this will cause undefined behavior.`
        // DispatchQueue.main.async solves the issue, but then NoConnectionFolderView appears for a split second after login or clearing cache.
        // Consider starting ViewModels with `isVisible = false` to fix that
        newChain.last?.onAppear() // current
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // Consider navigation in a following folder structure, down to folder 3 and then back one step:
        //
        //      My Files -> folder 1 -> folder 2 -> folder 3
        //                              folder 2 <-
        //
        // SwiftUI will keep FinderView and FinderCoordinator of `folder 3` in memory for the sake of optimisation,
        // but sometimes (state restoration, Create Folder option in Move) we need to know which of the FinderCoordinators is currently topmost.
        // We used to nullify nextFolderCoordinator in onAppear() call of FinderView, but iOS 14 sometimes wrongfully repeates this call
        // for root FinderView (`My Files`) when a sheet is opened by one of descendants.
        //
        // In this method we directly count number of FinderViews inside NavigationView and cut off connection
        // to FinderCoordinators of FinderViews that are no longer visible. In order to get this method called, RootView needs to be
        // a delegate of UINavigationController, which is done by RootDeeplinkableView inside Root[Move|Activity|Folder|Shared]Views.
        //
        // This method should only be called for the root FinderCoordinator in chain.
        
        let count = navigationController.viewControllers.count
        if case let coordinators = self.fullCoordinatorsChain, coordinators.count >= count {
            coordinators[count - 1].nextFolderCoordinator = nil
        }
    }
}
