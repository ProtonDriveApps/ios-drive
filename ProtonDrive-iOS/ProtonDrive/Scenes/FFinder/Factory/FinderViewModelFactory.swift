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
import PDSDKCore
import UIKit

/// Factory for creating Finder-related view models
@MainActor
struct FinderViewModelFactory {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    struct CellViewModelCreationParams {
        let actionHandler: FinderActionHandling?
        let isSharedWithMeRoot: Bool
        let node: NodeDTO
        let selectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>?
        let shouldDisable: Bool
        let supportSelection: Bool
    }

    func makeCellViewModel(parameters: CellViewModelCreationParams) -> FFinderCellViewModel {
        var menuVM: FFinderNodeActionMenuViewModel?
        if let actionHandler = parameters.actionHandler {
            menuVM = FFinderNodeActionMenuViewModel(
                actionHandler: actionHandler,
                featureFlagsController: dependencies.featureFlagsController,
                isSharedWithMeRoot: parameters.isSharedWithMeRoot,
                node: parameters.node
            )
        }
        return FFinderCellViewModel(
            dependencies: .init(
                actionViewModel: menuVM,
                featureFlagsController: dependencies.featureFlagsController,
                multipleSelectionModel: parameters.supportSelection ? parameters.selectionModel : nil,
                nodeStatePolicy: dependencies.nodeStatePolicy,
                progressTrackersController: dependencies.progressTrackersController,
                thumbnailLoader: dependencies.tower.sdkObjects.thumbnailDownloader,
                transferManager: dependencies.finderTransferManager
            ),
            state: .init(
                isSharedWithMeRoot: parameters.isSharedWithMeRoot,
                node: parameters.node,
                shouldDisable: parameters.shouldDisable
            )
        )
    }

    func makeActionMenuViewModel(
        actionHandler: FinderActionHandling,
        isSharedWithMeRoot: Bool,
        node: NodeDTO
    ) -> FFinderNodeActionMenuViewModel {
        FFinderNodeActionMenuViewModel(
            actionHandler: actionHandler,
            featureFlagsController: dependencies.featureFlagsController,
            isSharedWithMeRoot: isSharedWithMeRoot,
            node: node
        )
    }
}

extension FinderViewModelFactory {
    func makeFinderViewModel(
        for node: NodeDTO,
        coordinator: FFinderCoordinator
    ) -> FFinderViewModel {
        let tower = dependencies.tower
        let selectionModel = MMultipleSelectionModel<AnyVolumeIdentifier>()
        let actionHandler = makeActionHandler(
            coordinator: coordinator,
            node: node,
            selectionModel: selectionModel
        )

        let viewModel = FFinderViewModel(
            dependencies: .init(
                actionHandler: actionHandler,
                childrenSource: makeFolderChildrenSource(node: node),
                contactsManager: dependencies.contactsManager,
                context: dependencies.tower.storage.backgroundContext, 
                coordinator: coordinator,
                multipleSelectionModel: selectionModel,
                scene: makeFolderScene(
                    actionHandler: actionHandler,
                    selectionModel: selectionModel,
                    node: node
                ),
                scrollToTopPublisher: dependencies.scrollToTopPublisher,
                tower: tower,
                transferManager: dependencies.finderTransferManager,
                uploadSectionFactory: makeUploadSectionFactory(node: node, handler: actionHandler),
                viewModelFactory: self,
                volumeIdsController: tower.sharedVolumeIdsController
            ),
            folder: node
        )
        return viewModel
    }

    func makeMoveViewModel(
        for currentFolder: NodeDTO,
        selectedNodes: [NodeDTO],
        coordinator: FFinderCoordinator
    ) -> FFinderViewModel {
        let tower = dependencies.tower
        let actionHandler = makeActionHandler(coordinator: coordinator, node: currentFolder, selectionModel: nil)

        let viewModel = FFinderViewModel(
            dependencies: .init(
                actionHandler: actionHandler,
                childrenSource: makeFolderChildrenSource(node: currentFolder),
                contactsManager: dependencies.contactsManager,
                context: dependencies.tower.storage.backgroundContext,
                coordinator: coordinator,
                multipleSelectionModel: nil,
                scene: makeMoveScene(folder: currentFolder, selectedNodes: selectedNodes),
                scrollToTopPublisher: dependencies.scrollToTopPublisher,
                tower: tower,
                transferManager: dependencies.finderTransferManager,
                uploadSectionFactory: makeUploadSectionFactory(node: currentFolder, handler: actionHandler),
                viewModelFactory: self,
                volumeIdsController: tower.sharedVolumeIdsController
            ),
            folder: currentFolder
        )
        return viewModel
    }

    func makeIncomingFilesPickerViewModel(
        for currentFolder: NodeDTO,
        onSaveHere: @escaping (NodeDTO) -> Void,
        coordinator: FFinderCoordinator
    ) -> FFinderViewModel {
        let tower = dependencies.tower
        let actionHandler = makeActionHandler(coordinator: coordinator, node: currentFolder, selectionModel: nil)

        let viewModel = FFinderViewModel(
            dependencies: .init(
                actionHandler: actionHandler,
                childrenSource: makeFolderChildrenSource(node: currentFolder),
                contactsManager: dependencies.contactsManager,
                context: dependencies.tower.storage.backgroundContext,
                coordinator: coordinator,
                multipleSelectionModel: nil,
                scene: makeIncomingFilesPickerScene(folder: currentFolder, onSaveHere: onSaveHere),
                scrollToTopPublisher: dependencies.scrollToTopPublisher,
                tower: tower,
                transferManager: dependencies.finderTransferManager,
                uploadSectionFactory: makeUploadSectionFactory(node: currentFolder, handler: actionHandler),
                viewModelFactory: self,
                volumeIdsController: tower.sharedVolumeIdsController
            ),
            folder: currentFolder
        )
        return viewModel
    }

    private func makeFolderChildrenSource(node: NodeDTO) -> FolderChildrenSource {
        let tower = dependencies.tower
        let childrenFetcher = FolderChildrenFetcher(
            dependencies: .init(
                cloudSlot: tower.cloudSlot,
                localSettings: tower.localSettings,
                storageManager: tower.storage
            ),
            state: .init(nodeID: node.nodeIdentifier)
        )
        return FolderChildrenSource(
            tower: tower,
            folder: node,
            childrenFetcher: childrenFetcher
        )
    }

    private func makeActionHandler(
        coordinator: FFinderCoordinator,
        node: NodeDTO,
        selectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>?
    ) -> FinderActionHandler {
        let tower = dependencies.tower
        let bookmarkContainer = BookmarkContainer(
            tower: tower,
            featureFlagsController: dependencies.featureFlagsController
        )
        return FinderActionHandler(
            dependencies: .init(
                bookmarksContainer: bookmarkContainer,
                coordinator: coordinator,
                multipleSelectionModel: selectionModel,
                tower: tower,
                transferManager: dependencies.finderTransferManager
            ),
            folder: node
        )
    }

    private func makeFolderScene(
        actionHandler: FinderActionHandling,
        selectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>,
        node: NodeDTO
    ) -> FolderFinderScene {
        let userInfoController = UserInfoControllerFactory().makeController(
            sessionVault: dependencies.tower.sessionVault
        )
        return FolderFinderScene(
            dependencies: .init(
                actionHandler: actionHandler,
                featureFlagsController: dependencies.featureFlagsController,
                localSettings: dependencies.tower.localSettings,
                multipleSelectionModel: selectionModel,
                performanceMetricsController: dependencies.tower.performanceMetricsController,
                userInfoController: userInfoController,
                viewModelFactory: self
            ),
            folder: node
        )
    }

    private func makeMoveScene(folder: NodeDTO, selectedNodes: [NodeDTO]) -> MoveFinderScene {
        MoveFinderScene(folder: folder, selectedNodes: selectedNodes, viewModelFactory: self, tower: dependencies.tower)
    }

    private func makeIncomingFilesPickerScene(
        folder: NodeDTO,
        onSaveHere: @escaping (NodeDTO) -> Void
    ) -> IIncomingFilesPickerScene {
        IIncomingFilesPickerScene(folder: folder, onSaveHere: onSaveHere, viewModelFactory: self)
    }

    private func makeUploadSectionFactory(node: NodeDTO, handler: FinderActionHandler) -> UploadSectionFactory {
        UploadSectionFactory(
            featureFlagsController: dependencies.featureFlagsController,
            isSourceTypeAvailable: UIImagePickerController.isSourceTypeAvailable,
            node: node,
            handler: handler
        )
    }
}

extension FinderViewModelFactory {
    struct Dependencies {
        let contactsManager: ContactsManagerProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let finderTransferManager: FinderTransferManaging
        let nodeStatePolicy: NodeStatePolicy
        let progressTrackersController: ProgressTrackersControllerProtocol
        let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>
        let tower: Tower
    }
}
