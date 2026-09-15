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
import CoreData
import Foundation
import PDContacts
import PDCore
import PDCoreIOS
import PDLocalization
import PDSDKCore
import PDSDKCoreiOS
import ProtonCoreAuthentication
import ProtonCoreUIFoundations
import UIKit

@MainActor
final class FFinderCoordinator: NSObject {
    private let dependencies: Dependencies
    var authenticator: Authenticator { dependencies.container.authenticator }
    var tower: Tower { dependencies.tower }
    var volumeLockController: VolumeLockController { dependencies.container.volumeLockController }
    /// Fires after `dismiss()`'s animation completes. Useful for transient
    /// coordinators (e.g. the IncomingFiles picker) that need to break their
    /// internal retain cycle once the modal goes away.
    var onDismissed: (() -> Void)?
    private var fileExportViewModel: FileExportViewModel?
    private var filePickerCoordinator: FilePickerCoordinator?
    private var moveNavigationController: UINavigationController?
    private var incomingFilesSaveHandler: ((NodeDTO) -> Void)?
    private(set) weak var navigationController: UINavigationController?
    private lazy var createDocView = makeCreateDocumentView(fileType: .doc)
    private lazy var createSheetView = makeCreateDocumentView(fileType: .sheet)

    private var activeNavigationController: UINavigationController? {
        moveNavigationController ?? navigationController
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies

        super.init()
    }

    func start(location: Location, deeplink: Deeplink? = nil) -> UIViewController {
        let stubVC = UIViewController()
        stubVC.view.backgroundColor = ColorProvider.BackgroundNorm
        let navigationController = UINavigationController(rootViewController: stubVC)

        Task { @MainActor in
            switch location {
            case .myFinderRoot:
                await startFinderRoot(deeplink: deeplink)
            case let .incomingFilesPickerRoot(onSaveHere):
                await startIncomingFilesPicker(onSaveHere: onSaveHere)
            }
        }
        self.navigationController = navigationController
        return navigationController
    }
}

extension FFinderCoordinator {
    private func startFinderRoot(deeplink: Deeplink?) async {
        guard let root = await getMyFinderRoot() else {
            assertionFailure("Should be able to get node")
            return
        }
        let rootVC = makeFolderViewController(node: root)

        let chain = await buildDeeplinkFolderChain(deeplink: deeplink, rootIdentifier: root.nodeIdentifier)
        let chainVCs = chain.map { makeFolderViewController(node: $0) }
        navigationController?.setViewControllers([rootVC] + chainVCs, animated: false)

        let topFolder = chain.last ?? root
        await handleDeeplinkTerminal(deeplink: deeplink, topFolder: topFolder)
        deeplink?.invalidate()
    }

    private func startIncomingFilesPicker(onSaveHere: @escaping (NodeDTO) -> Void) async {
        guard let root = await getMyFinderRoot() else {
            assertionFailure("Should be able to get node")
            return
        }
        incomingFilesSaveHandler = onSaveHere
        let viewModel = dependencies.viewModelFactory.makeIncomingFilesPickerViewModel(
            for: root,
            onSaveHere: onSaveHere,
            coordinator: self
        )
        let viewController = FFinderView(viewModel: viewModel).embeddedInHostingController()
        navigationController?.setViewControllers([viewController], animated: false)
    }
}

// MARK: - Navigation
extension FFinderCoordinator {
    func presentNodeDetail(node: NodeDTO) {
        Task { @MainActor in
            let vc = await NodeDetailsFactory(tower: dependencies.tower).makeDetailsView(for: node)
            navigationController?.present(vc, animated: true)
        }
    }
    
    func presentFileExport(node: NodeDTO, isDownload: Bool) {
        fileExportViewModel = FileExportFactory().makeViewModel(tower: tower, rootViewController: navigationController)
        Task.detached { [weak self] in
            await self?.fileExportViewModel?.export(files: [node], isDownloadDestination: isDownload)
        }
    }

    func presentBatchFileExport(nodes: [NodeDTO]) {
        fileExportViewModel = FileExportFactory().makeViewModel(tower: tower, rootViewController: navigationController)
        Task.detached { [weak self] in
            await self?.fileExportViewModel?.export(files: nodes, isDownloadDestination: true)
        }
    }
    
    func showFolder(node: NodeDTO) {
        let viewController = makeFolderViewController(node: node)
        navigationController?.show(viewController, sender: nil)
    }

    func presentMoveToFinderBrowser(selectedNodes: [NodeDTO]) {
        Task { @MainActor in
            guard let root = await getMyFinderRoot() else {
                assertionFailure("Should be able to get node")
                return
            }
            let viewModel = dependencies.viewModelFactory.makeMoveViewModel(
                for: root,
                selectedNodes: selectedNodes,
                coordinator: self
            )
            let viewController = FFinderView(viewModel: viewModel).embeddedInHostingController()
            let nav = UINavigationController(rootViewController: viewController)
            nav.isModalInPresentation = true
            nav.presentationController?.delegate = self
            moveNavigationController = nav
            navigationController?.present(nav, animated: true)
        }
    }

    func showFolderInMoveToFinderBrowser(selectedNodes: [NodeDTO], folder: NodeDTO) {
        guard let moveNavigationController else { return }
        let viewModel = dependencies.viewModelFactory.makeMoveViewModel(
            for: folder,
            selectedNodes: selectedNodes,
            coordinator: self
        )
        let viewController = FFinderView(viewModel: viewModel).embeddedInHostingController()
        moveNavigationController.show(viewController, sender: nil)
    }

    func showFolderInIncomingFilesPicker(folder: NodeDTO) {
        guard let onSaveHere = incomingFilesSaveHandler else { return }
        let viewModel = dependencies.viewModelFactory.makeIncomingFilesPickerViewModel(
            for: folder,
            onSaveHere: onSaveHere,
            coordinator: self
        )
        let viewController = FFinderView(viewModel: viewModel).embeddedInHostingController()
        navigationController?.show(viewController, sender: nil)
    }

    func presentRename(node: NodeDTO) {
        let vc = EEditNodeCoordinator().start((dependencies.tower, .rename(node: node)))
        navigationController?.present(vc, animated: true)
    }

    func presentCreateFolder(parent: CoreDataFolder) {
        let vc = EEditNodeCoordinator().start((dependencies.tower, .create(parent: parent)))
        activeNavigationController?.present(vc, animated: true)
    }

    func presentConfigShareMember(node: NodeDTO) {
        Task { @MainActor in
            guard let coreDataNode: Node = await coreDataNode(for: node) else { return }
            let deps = SharingMemberStartDependencies(
                tower: tower,
                contactsManager: dependencies.contactsManager,
                featureFlagsController: dependencies.featureFlagsController,
                invitationResultController: nil,
                rootViewController: navigationController
            )
            SharingMemberStartFactory()
                .makeCoordinator(dependencies: deps, node: coreDataNode)
                .openSharingConfig(sharingType: .common)
        }
    }

    func presentOpenInBrowser(node: NodeDTO) {
        Task { @MainActor in
            guard let file: CoreDataFile = await coreDataNode(for: node) else { return }
            dependencies.container.protonFileContainer
                .makeController(rootViewController: navigationController)
                .openExternally(file.identifier)
        }
    }

    func presentTrashAlert(nodes: [NodeDTO], onConfirm: @escaping () -> Void) {
        let (title, button) = trashText(nodes: nodes)
        presentAlert(message: title, actionTitle: button, action: onConfirm)
    }

    func presentRemoveMeAlert(node: NodeDTO, onConfirm: @escaping () -> Void) {
        let message = Localization.shared_with_me_remove_me(item: node.name)
        let actionTitle = Localization.shared_with_me_remove_me_confirmation
        presentAlert(message: message, actionTitle: actionTitle, action: onConfirm)
    }

    func presentRemoveBookmarkAlert(node: NodeDTO, onConfirm: @escaping () -> Void) {
        let message = Localization.shared_with_me_bookmarks_delete_button(item: node.name)
        let actionTitle = Localization.general_delete
        presentAlert(message: message, actionTitle: actionTitle, action: onConfirm)
    }

    func presentDocumentScanner(from folder: NodeDTO) {
        filePickerCoordinator = FilePickerCoordinator(parentCoordinator: self, featureFlagsController: dependencies.featureFlagsController)
        filePickerCoordinator?.presentScanner(parentFolder: folder)
    }

    func presentCreateDocument(parentIdentifier: NodeIdentifier, type: ProtonFileType) {
        switch type {
        case .doc:
            createDocView.start(with: parentIdentifier)
        case .sheet:
            createSheetView.start(with: parentIdentifier)
        }
    }

    func presentPhotoPicker(from folder: NodeDTO) {
        filePickerCoordinator = FilePickerCoordinator(parentCoordinator: self, featureFlagsController: dependencies.featureFlagsController)
        filePickerCoordinator?.presentPhotoLibraryPicker(parentFolder: folder)
    }

    func presentCamera(from folder: NodeDTO) {
        filePickerCoordinator = FilePickerCoordinator(parentCoordinator: self, featureFlagsController: dependencies.featureFlagsController)
        filePickerCoordinator?.presentCamera(parentFolder: folder)
    }

    func presentDocumentPicker(from folder: NodeDTO) {
        filePickerCoordinator = FilePickerCoordinator(parentCoordinator: self, featureFlagsController: dependencies.featureFlagsController)
        filePickerCoordinator?.presentDocumentPicker(parentFolder: folder)
    }

    func openBookmark(node: NodeDTO) {
        Task {
            let context = dependencies.tower.storage.backgroundContext
            guard let bookmark: CoreDataBookmark = await coreDataNode(for: node, context: context) else { return }
            let container = BookmarkContainer(
                tower: dependencies.tower,
                featureFlagsController: dependencies.featureFlagsController
            )
            let controller = container.makeController(for: bookmark)
            await controller.open()
        }
    }

    func openProtonFile(node: NodeDTO) {
        let controller = dependencies.container.protonFileContainer.makeController(rootViewController: navigationController)
        controller.openPreview(node.nodeIdentifier)
    }

    func openFilePreview(node: NodeDTO, shouldReportPerformance: Bool) {
        let context = dependencies.tower.storage.backgroundContext
        Task.detached { [weak self] in
            guard let self else { return }
            guard let file: CoreDataFile = await coreDataNode(for: node, context: context) else { return }
            // Create the repository and coordinator
            let repository = CoreDataFilePreviewRepository(context: context, file: file)
            let performanceMetrics = await dependencies.tower.performanceMetricsController
            let coordinator = await FilePreviewPreparationCoordinator(
                messageHandler: UserMessageHandler(),
                repository: repository,
                performanceMetricsController: shouldReportPerformance ? performanceMetrics : nil,
                root: self.navigationController
            )
            await coordinator.preview()
        }
    }

    func presentTechnicalError(message: String) {
        let vc = TTechnicalErrorPlaceholderView(message: message).embeddedInHostingController()
        navigationController?.present(vc, animated: true)
    }

    func openSubscriptions() {
        let viewController = dependencies.container.makeSubscriptionsViewController()
        let subscriptionNav = ModalNavigationViewController(rootViewController: viewController)
        subscriptionNav.modalPresentationStyle = .fullScreen
        navigationController?.present(subscriptionNav, animated: true)
    }

    func presentNoSpaceView(storage: NNoSpaceView.Storage) {
        let view = NNoSpaceView(storage: storage).embeddedInHostingController()
        navigationController?.present(view, animated: true)
    }

    func navigateBack() {
        if let moveNavigationController, moveNavigationController.viewControllers.count > 1 {
            moveNavigationController.popViewController(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    func dismiss() {
        navigationController?.dismiss(animated: true) { [weak self] in
            self?.moveNavigationController = nil
            self?.onDismissed?()
        }
    }

    /// Empties the navigation stack so the FFinderViewModel/scene/dependencies
    /// chain that points back at this coordinator can be released. Call this
    /// once the modal is fully gone — typically from `onDismissed` — for
    /// short-lived (single-session) coordinators.
    func tearDown() {
        navigationController?.setViewControllers([], animated: false)
        incomingFilesSaveHandler = nil
        onDismissed = nil
    }
}

extension FFinderCoordinator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        moveNavigationController = nil
    }
}

extension FFinderCoordinator: PickerCoordinator {
    func picker(didFinishPicking items: [URLResult], to folder: NodeDTO) {
        dismissPicker { [weak self] in
            guard let self else { return }
            Task {
                var errors = [Error]()
                for item in items {
                    switch item {
                    case .success(let content):
                        do {
                            try await self.dependencies.transferManager.uploadFile(content, to: folder)
                        } catch {
                            if let uploadError = error as? SDKUploadErrors, uploadError == .cancelled {
                                continue
                            }
                            errors.append(error)
                        }
                    case .failure(let error):
                        Log.error("Import file failed", error: error, domain: .itemProviderLoader)
                        errors.append(error)
                    }
                }

                if !errors.isEmpty {
                    let error = PickerError.importFailures(errors: errors)
                    for importError in errors {
                        if let error = importError as? SDKUploadErrors, error == .noSpaceOnLocal {
                            self.presentNoSpaceView(storage: .local)
                            return
                        } else if (importError as NSError).isNoSpaceOnDevice {
                            self.presentNoSpaceView(storage: .local)
                            return
                        }
                    }
                    self.dependencies.userMessageHandler.handleError(error)
                }
            }
        }
    }

    func dismissPicker(completion: (() -> Void)? = nil) {
        filePickerCoordinator = nil
        guard let presentedViewController = navigationController?.presentedViewController else {
            completion?()
            return
        }
        presentedViewController.dismiss(animated: true, completion: completion)
    }
}

// MARK: Navigation helper
extension FFinderCoordinator {
    private func trashText(nodes: [NodeDTO]) -> (title: String, button: String) {
        if nodes.count == 1, nodes.first?.isFile ?? false {
            return (Localization.action_trash_files_alert_message(num: 1), Localization.general_remove_files(num: 1))
        } else if nodes.count == 1, nodes.first?.isFolder ?? false {
            return (Localization.action_trash_folders_alert_message(num: 1), Localization.general_remove_folders(num: 1))
        } else if nodes.allSatisfy({ $0.isFile }) {
            return (Localization.action_trash_files_alert_message(num: nodes.count), Localization.general_remove_files(num: nodes.count))
        } else if nodes.allSatisfy({ $0.isFolder }) {
            return (Localization.action_trash_folders_alert_message(num: nodes.count), Localization.general_remove_folders(num: nodes.count))
        } else {
            return (Localization.action_trash_items_alert_message(num: nodes.count), Localization.general_remove_items(num: nodes.count))
        }
    }

    private func makeCreateDocumentView(fileType: ProtonFileType) -> NewProtonFileLoadingView {
        let factory = NewProtonFileFactory()
        return factory.makeView(
            tower: tower,
            previewContainer: dependencies.container.protonFileContainer,
            fileType: fileType
        )
    }

    private func coreDataNode<T: Node>(for nodeDTO: NodeDTO, context: NSManagedObjectContext? = nil) async -> T? {
        let context = context ?? tower.storage.mainContext
        return await context.perform {
            try? context.typedObject(with: nodeDTO.objectID) as T
        }
    }

    private func presentAlert(message: String, actionTitle: String, action: @escaping () -> Void) {
        let style: UIAlertController.Style = UIDevice.current.isIpad ? .alert : .actionSheet
        let alert = UIAlertController(title: nil, message: message, preferredStyle: style)
        alert.addAction(
            UIAlertAction(title: actionTitle, style: .destructive, handler: { _ in
                action()
            })
        )
        alert.addAction(UIAlertAction(title: Localization.general_cancel, style: .cancel))
        navigationController?.present(alert, animated: true)
    }

    private func getNode(_ nodeIdentifier: NodeIdentifier) async -> NodeDTO? {
        try? await tower.storage.backgroundContextPool.performInContext { context in
            guard let node = Node.fetch(identifier: nodeIdentifier, allowSubclasses: true, in: context) else {
                throw CoreDataNode.InvalidState(message: "failed to get node from local database")
            }
            return try? NodeDTO(node: node, signatureKeys: [])
        }
    }

    private func getMyFinderRoot() async -> NodeDTO? {
        let fetcher = MyFilesRootFetcher(storage: dependencies.tower.storage)
        let nodeIdentifier = fetcher.getRoot()
        return await getNode(nodeIdentifier)
    }

    private func makeFinderViewModel(node: NodeDTO) -> FFinderViewModel {
        dependencies.viewModelFactory.makeFinderViewModel(
            for: node,
            coordinator: self
        )
    }

    private func makeFolderViewController(node: NodeDTO) -> UIViewController {
        let viewModel = makeFinderViewModel(node: node)
        return FFinderView(viewModel: viewModel).embeddedInHostingController()
    }
}

// MARK: - Deeplink
extension FFinderCoordinator {
    /// Resolves the folder chain encoded in `deeplink` (excluding the root, which the
    /// caller has already produced). Stops at the first identifier that cannot be
    /// resolved or is not a folder, returning whatever was resolved so far so the user
    /// at least lands on the deepest cached parent.
    private func buildDeeplinkFolderChain(
        deeplink: Deeplink?,
        rootIdentifier: NodeIdentifier
    ) async -> [NodeDTO] {
        guard let deeplink else { return [] }
        var folders: [NodeDTO] = []
        var previous: NodeIdentifier? = rootIdentifier
        while let next = deeplink.next(after: previous) {
            guard let node = await getNode(next), node.isFolder else { break }
            folders.append(node)
            previous = next
        }
        return folders
    }

    private func handleDeeplinkTerminal(deeplink: Deeplink?, topFolder: NodeDTO) async {
        guard let deeplink else { return }
        if let modalID = deeplink.finalModal(), let modal = await getNode(modalID), modal.isFile {
            openDeeplinkFile(node: modal)
        } else if let action = deeplink.finalAction() {
            switch action {
            case .scanDocument:
                presentDocumentScanner(from: topFolder)
            }
        }
    }

    private func openDeeplinkFile(node: NodeDTO) {
        if node.isProtonFile {
            openProtonFile(node: node)
        } else if node.isBookmark {
            openBookmark(node: node)
        } else {
            openFilePreview(node: node, shouldReportPerformance: false)
        }
    }
}

extension FFinderCoordinator {
    struct Dependencies {
        let container: AuthenticatedDependencyContainer
        let progressTrackersController = ProgressTrackersController()
        let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?
        let transferManager: FinderTransferManaging
        let userMessageHandler: UserMessageHandlerProtocol
        let viewModelFactory: FinderViewModelFactory
        var contactsManager: ContactsManagerProtocol { container.contactsManager }
        var featureFlagsController: FeatureFlagsControllerProtocol { container.featureFlagsController }
        var tower: Tower { container.tower }

        @MainActor
        init(
            container: AuthenticatedDependencyContainer,
            scrollToTopPublisher: AnyPublisher<TabBarItem, Never>?,
            userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
        ) {
            self.container = container
            self.scrollToTopPublisher = scrollToTopPublisher
            self.transferManager = FinderTransferManager(
                progressTrackersController: progressTrackersController,
                tower: container.tower
            )
            transferManager.startMonitor()
            self.userMessageHandler = userMessageHandler
            self.viewModelFactory = FinderViewModelFactory(
                dependencies: .init(
                    contactsManager: container.contactsManager,
                    featureFlagsController: container.featureFlagsController,
                    finderTransferManager: transferManager,
                    nodeStatePolicy: FileNodeStatePolicy(),
                    progressTrackersController: progressTrackersController,
                    scrollToTopPublisher: scrollToTopPublisher ?? Empty<TabBarItem, Never>().eraseToAnyPublisher(),
                    tower: container.tower
                )
            )
        }
    }

    enum Location {
        case myFinderRoot
        case incomingFilesPickerRoot(onSaveHere: (NodeDTO) -> Void)
    }
}
