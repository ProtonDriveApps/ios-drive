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
import Foundation
import SwiftUI
import UIKit
import PDCore
import PDUIComponents
import ProtonCoreUIFoundations
import PDLocalization

class FinderCoordinator: NSObject, ObservableObject, SwiftUICoordinator {
    enum Context {
        case move(rootNode: NodeIdentifier, nodesToMove: [NodeIdentifier], nodeToMoveParent: NodeIdentifier)
        case folder(nodeID: NodeIdentifier)
        case shared
        case offlineAvailable
        case sharedWithMe
    }

    private let container: AuthenticatedDependencyContainer
    private var tower: Tower {
        container.tower
    }

    var featureFlagsController: FeatureFlagsControllerProtocol {
        container.featureFlagsController
    }

    private let deeplink: Deeplink?
    private let photoPickerCoordinator: PhotosPickerCoordinator?
    private let isSharedWithMe: Bool
    private(set) var onDisappear: () -> Void = { }
    private(set) var onAppear: () -> Void = { }
    private(set) var model: FinderModel? // Previously we had it weak but iOS 14 was mysteriously nullifying it after some Move manipulations - see DRVIOS-581
    private(set) weak var previousFolderCoordinator: FinderCoordinator?
    private(set) weak var nextFolderCoordinator: FinderCoordinator?
    private lazy var createDocumentView = makeCreateDocumentView()
    weak var rootViewController: UIViewController?

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
    } set: {  [weak self] destination in
        guard let self else { return }
        // Default case opens SwiftUI modal. Non-swiftui handling needs to be overriden here.
        switch destination {
        case let .file(file: file, share: share):
            self.openFilePreview(file: file, share: share)
        case let .protonDocument(file):
            self.openProtonDocument(with: file)
        case let .openInBrowser(file):
            self.openProtonDocumentInBrowser(with: file)
        case let .configShareMember(node: node):
            self.openSharingMemberConfiguration(node: node)
        case let .createDocument(parentIdentifier):
            self.createDocumentView.start(with: parentIdentifier)
        default:
            self._presentedModal = destination
        }
    }

    init(container: AuthenticatedDependencyContainer, isSharedWithMe: Bool = false, parent: FinderCoordinator? = nil, deeplink: Deeplink? = nil, photoPickerCoordinator: PhotosPickerCoordinator? = nil) {
        self.container = container
        self.isSharedWithMe = isSharedWithMe
        self.deeplink = deeplink
        self.previousFolderCoordinator = parent
        self.photoPickerCoordinator = photoPickerCoordinator
        self.rootViewController = parent?.rootViewController
    }
}

// MARK: - start(_:)

extension FinderCoordinator {
    func start(_ context: Context) -> some View {
        defer { self.deeplink(from: deeplink, tower: tower) }
        log(context: context)
        return self.startView(context)
    }

    @ViewBuilder
    private func startView(_ context: Context) -> some View {
        switch context {
        case let .move(nodeID, nodesToMoveID, nodeToMoveParent):
            if let node = tower.uiSlot?.subscribeToNode(nodeID) as? Folder {
                self.startMove(nodeID, nodesToMoveID, nodeToMoveParent, node)
            } else {
                TechnicalErrorPlaceholderView(message: Localization.finder_coordinator_move_invalid_node)
            }

        case let .folder(nodeID):
            if let node = tower.uiSlot?.subscribeToNode(nodeID) as? Folder {
                self.startFolder(nodeID, node)
            } else {
                TechnicalErrorPlaceholderView(message: Localization.finder_coordinator_invalid_folder)
            }

        case .offlineAvailable:
            self.startOfflineAvailable()

        case .shared:
            if let volumeId = tower.uiSlot.getVolumeId() {
                self.startShared(volumeID: volumeId)
            } else {
                TechnicalErrorPlaceholderView(message: Localization.finder_coordinator_invalid_shared_folder)
            }
        case .sharedWithMe:
            self.startSharedWithMe()
        }
    }
    
    private func log(context: Context) {
        switch context {
        // Only log unexpected folder behavior to avoid spamming the log.
        case let .folder(nodeID):
            if tower.uiSlot == nil {
                Log.info("Attempt to open folder but uiSlot is nil", domain: .application)
                return
            }
            guard let node = tower.uiSlot?.subscribeToNode(nodeID) else {
                Log.error("Attempt to open folder but NodeID \(nodeID) doesn't exist", domain: .application)
                return
            }
            if (node as? Folder) != nil {
                Log.info("Open folder \(nodeID)", domain: .application)
            } else {
                Log.error("Attempt to open folder but node is not a folder type", domain: .application)
            }
        default:
            break
        }
    }

    private func startMove(_ nodeID: NodeIdentifier, _ nodesToMoveID: [NodeIdentifier], _ nodeToMoveParent: NodeIdentifier, _ node: Folder) -> some View {
        let model = MoveModel(tower: tower, node: node, nodeID: nodeID, nodesToMoveID: nodesToMoveID, nodeToMoveParentID: nodeToMoveParent)
        self.model = model
        let viewModel = MoveViewModel(model: model, node: node, featureFlagsController: featureFlagsController)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }

    private func startOfflineAvailable() -> some View {
        let model = OfflineAvailableModel(tower: tower)
        self.model = model
        let viewModel = OfflineAvailableViewModel(model: model, featureFlagsController: featureFlagsController)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }

    @ViewBuilder
    private func startShared(volumeID: String) -> some View {
        if featureFlagsController.hasSharing {
            startSharedByMe(volumeID: volumeID)
        } else {
            startPublicLinkShared(volumeID: volumeID)
        }
    }

    private func startPublicLinkShared(volumeID: String) -> some View {
        let model = SharedModel(tower: tower, volumeID: volumeID)
        self.model = model
        let viewModel = SharedViewModel(model: model, featureFlagsController: featureFlagsController)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }

    private func startSharedByMe(volumeID: String) -> some View {
        let model = SharedByMeModel(tower: tower, volumeID: volumeID)
        self.model = model
        let viewModel = SharedByMeViewModel(model: model, featureFlagsController: featureFlagsController)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }

    private func startSharedWithMe() -> some View {
        let model = SharedWithMeModel(tower: tower)
        self.model = model
        let starter = SynchronizingInMemorySharedWithMeStarter(client: tower.client, storage: tower.storage, sharedVolumesEventsController: container.sharedVolumesEventsContainer.controller)
        let cacher = CoredataSharedWithMeLinkMetadataCache(storage: tower.storage)
        let retriever = SharedWithMeLinksMetadataRetriever(client: tower.client, dataSource: starter, cacher: cacher)
        let viewModel = SharedWithMeViewModel(model: model, starter: starter, retriever: retriever, featureFlagsController: featureFlagsController, volumeIdsController: tower.sharedVolumeIdsController)
        self.hookIntoViewLifecycle(viewModel)
        return FinderView(vm: viewModel, coordinator: self, presentModal: presentModal, drilldownTo: drilldownTo)
    }

    private func startFolder(_ nodeID: NodeIdentifier, _ node: Folder) -> some View {
        let model = FolderModel(tower: tower, node: node, nodeID: nodeID)
        self.model = model
        let viewModel = FolderViewModel(localSettings: tower.localSettings, model: model, node: node, nodeStatePolicy: FileNodeStatePolicy(), featureFlagsController: featureFlagsController, isSharedWithMe: isSharedWithMe, volumeIdsController: tower.sharedVolumeIdsController)
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
                TechnicalErrorPlaceholderView(message: Localization.finder_coordinator_invalid_go_move)
            }

        case .file:
            // Use UIKit to present file preview rather than SwiftUI, check FileCoordinator
            EmptyView()

        case .protonDocument:
            // Should be opened directly
            EmptyView()

        case .openInBrowser:
            // Should be opened directly
            EmptyView()

        case .createDocument:
            // Should be handled directly
            EmptyView()

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
            EditNodeCoordinator().start((tower, .create(parent: parent)))
                .edgesIgnoringSafeArea(.bottom)

        case let .rename(node) where node.parentLink != nil:
            EditNodeCoordinator().start((tower, .rename(node: node)))
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
        let coordinator = FinderCoordinator(container: container, parent: self, deeplink: deeplink)
        nextFolderCoordinator = coordinator
        return coordinator.start(.move(rootNode: folder.identifier, nodesToMove: nodesToMoveID, nodeToMoveParent: nodeToMoveParentID))
    }

    private func goFolder(_ folder: Folder) -> some View {
        let coordinator = FinderCoordinator(container: container, isSharedWithMe: self.isSharedWithMe, parent: self, deeplink: deeplink, photoPickerCoordinator: photoPickerCoordinator)
        nextFolderCoordinator = coordinator
        return coordinator.start(.folder(nodeID: folder.identifier))
    }

    private func goMove(_ firstNode: Node, _ nodes: [Node], _ rootId: NodeIdentifier, _ parentId: NodeIdentifier) -> some View {
        let nodeIds = nodes.map(\.identifier)
        let coordinator = FinderCoordinator(container: container, deeplink: nil) // no connection to parent (current one) as new one is a root of new chain
        return RootMoveView(coordinator: coordinator, nodes: nodeIds, root: rootId, parent: parentId)
    }

    private func openProtonDocument(with file: File) {
        let controller = container.protonDocumentContainer.makeController(rootViewController: rootViewController)
        controller.openPreview(file.identifier)
    }

    private func openProtonDocumentInBrowser(with file: File) {
        let controller = container.protonDocumentContainer.makeController(rootViewController: rootViewController)
        controller.openExternally(file.identifier)
    }

    private func openFilePreview(file: File, share: Bool) {
        // Create the repository and coordinator
        let repository = CoreDataFilePreviewRepository(context: tower.storage.backgroundContext, file: file)
        let coordinator = FilePreviewPreparationCoordinator(repository: repository, root: rootViewController, share: share)
        let vm = FilePreviewPreparationViewModel(repository: repository, coordinator: coordinator, errorHandler: UserMessageHandler())

        // Create the alert view to indicate the decryption process
        let alert = UIAlertController(title: vm.title, message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: vm.cancelTitle, style: .cancel) { _ in vm.cancel() }
        alert.addAction(cancelAction)

        coordinator.presentingController = alert

        rootViewController?.present(alert, animated: true, completion: { [vm] in vm.prepareFile() })
    }

    private func openPreview(repository: FilePreviewRepository, share: Bool) -> UIViewController {
        let model = FileModel(repository: repository)
        let vc = PMPreviewController()
        vc.model = model
        vc.delegate = model
        vc.dataSource = model
        vc.share = share
        vc.modalPresentationStyle = .fullScreen
        vc.isModalInPresentation = false
        return vc
    }

    private func openSharingMemberConfiguration(node: Node) {
        let shareCreator = ShareCreator(
            storage: tower.storage,
            sessionVault: tower.sessionVault,
            cloudShareCreator: tower.client.createShare,
            signersKitFactory: tower.sessionVault,
            moc: tower.storage.backgroundContext
        )
        let dependencies = SharingMemberCoordinator.Dependencies(
            baseHost: tower.client.service.configuration.baseHost,
            client: tower.client,
            contactsManager: container.contactsManager, 
            entitlementsManager: tower.entitlementsManager,
            featureFlagsController: container.featureFlagsController,
            node: node,
            rootViewController: rootViewController,
            sessionVault: tower.sessionVault,
            shareCreator: shareCreator, 
            storage: tower.storage
        )
        SharingMemberCoordinator(dependencies: dependencies)
            .openSharingConfig()
    }

    private func makeCreateDocumentView() -> NewDocumentLoadingView {
        let factory = NewDocumentFactory()
        return factory.makeView(tower: tower, previewContainer: container.protonDocumentContainer)
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
