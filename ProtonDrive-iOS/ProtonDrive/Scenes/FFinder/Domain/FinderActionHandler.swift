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

import CoreData
import Foundation
import PDCore
import PDCoreIOS
import PDSDKCore
import PDUIComponents
import ProtonCoreNetworking

typealias FinderActionHandling = UploadSectionActionHandler &
FFinderNodeActionMenuHandling &
MultipleSelectionActionHandling &
FinderOverlayActionHandling

@MainActor
protocol MultipleSelectionActionHandling {
    func handleMultipleSelectionAction(_ action: ActionBarButtonViewModel, nodes: [NodeDTO])
}

@MainActor
protocol FinderOverlayActionHandling {
    func handleOverlayAction(_ action: ActionBarButtonViewModel)
}

@MainActor
final class FinderActionHandler {
    let dependencies: Dependencies
    let folder: NodeDTO

    init(dependencies: Dependencies, folder: NodeDTO) {
        self.dependencies = dependencies
        self.folder = folder
    }

    deinit {
        dependencies.tower.storage.synchronousContextPool.relinquish(dependencies.context)
    }

    private func coreDataNode<T: Node>(for nodeDTO: NodeDTO, context: NSManagedObjectContext? = nil) async -> T? {
        let context = context ?? dependencies.context
        return await context.perform { [context] in
            try? context.typedObject(with: nodeDTO.objectID) as T
        }
    }
}

// MARK: - Handler for `+` menu
extension FinderActionHandler: UploadSectionActionHandler {
    func handle(action: UploadSectionItem) {
        switch action {
        case .importFile:
            dependencies.coordinator.presentDocumentPicker(from: folder)
        case .uploadPhoto:
            dependencies.coordinator.presentPhotoPicker(from: folder)
        case .takePhoto:
            dependencies.coordinator.presentCamera(from: folder)
        case .createFolder:
            createFolder()
        case .createDocument:
            dependencies.coordinator.presentCreateDocument(parentIdentifier: folder.nodeIdentifier, type: .doc)
        case .createSheet:
            dependencies.coordinator.presentCreateDocument(parentIdentifier: folder.nodeIdentifier, type: .sheet)
        case .scanDocument:
            dependencies.coordinator.presentDocumentScanner(from: folder)
        }
    }

    private func createFolder() {
        Task { [weak self] in
            guard
                let self,
                let folder: CoreDataFolder = await coreDataNode(for: self.folder)
            else { return }
            self.dependencies.coordinator.presentCreateFolder(parent: folder)
        }
    }
}

// MARK: - Handler for more button menu in finder cell
extension FinderActionHandler: FFinderNodeActionMenuHandling {
    func configShareMember(node: NodeDTO) {
        dependencies.coordinator.presentConfigShareMember(node: node)
    }

    func copyBookmark(node: NodeDTO) {
        Task { [weak self] in
            guard
                let self,
                let bookmark: CoreDataBookmark = await coreDataNode(for: node)
            else { return }
            dependencies.bookmarksContainer
                .makeBookmarkManagerViewMode(for: bookmark)
                .copyBookmarkUrl()
        }
    }

    func downloadToDevice(node: NodeDTO) {
        dependencies.coordinator.presentFileExport(node: node, isDownload: true)
    }

    func move(node: NodeDTO) {
        dependencies.coordinator.presentMoveToFinderBrowser(selectedNodes: [node])
    }

    func openIn(node: NodeDTO) {
        dependencies.coordinator.presentFileExport(node: node, isDownload: false)
    }

    func openInBrowser(node: NodeDTO) {
        dependencies.coordinator.presentOpenInBrowser(node: node)
    }

    func pauseUpload(node: NodeDTO) {
        Task {
            await dependencies.transferManager.pauseUpload(id: node.id)
        }
    }

    func removeBookmark(node: NodeDTO) {
        dependencies.coordinator.presentRemoveBookmarkAlert(node: node) {
            Task { [weak self] in
                guard
                    let self,
                    let bookmark: CoreDataBookmark = await coreDataNode(for: node)
                else { return }
                dependencies.bookmarksContainer
                    .makeBookmarkManagerViewMode(for: bookmark)
                    .deleteBookmark()
            }
        }
    }

    func removeMe(node: NodeDTO) {
        guard let membership = node.membership else { return }
        let shareID = membership.shareID
        let memberID = membership.memberID
        let context = dependencies.context
        dependencies.coordinator.presentRemoveMeAlert(node: node) { [weak self] in
            Task {
                do {
                    self?.dependencies.multipleSelectionModel?.setSelectionMode(enabled: false)
                    try await self?.dependencies.tower.removeMember(shareID: shareID, memberID: memberID)
                    try await context.perform {
                        let currentNode: Node? = try context.typedObject(with: node.objectID)
                        if let folder = currentNode as? CoreDataFolder {
                            folder.isolateChildrenToPreventCascadeDeletion()
                        }
                        if let currentNode { context.delete(currentNode) }
                        if let shareObjectID = node.directShareObjectID,
                           let shareObj = try? context.existingObject(with: shareObjectID) {
                            context.delete(shareObj)
                        }
                        try context.saveOrRollback()
                    }
                } catch {
                    let error: Error = (error as? ResponseError)?.underlyingError ?? error
                    self?.dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
                }
            }
        }
    }

    func removeUpload(node: NodeDTO) {
        Task {
           await dependencies.transferManager.cancelUpload(id: node.id)
        }
    }

    func rename(node: NodeDTO) {
        dependencies.coordinator.presentRename(node: node)
    }

    func restartUpload(node: NodeDTO) {
        Task {
            await dependencies.transferManager.restartUpload(id: node.id)
        }
    }

    func showDetails(node: NodeDTO) {
        dependencies.coordinator.presentNodeDetail(node: node)
    }

    func toggleAvailableOffline(node: NodeDTO) {
        Task {
            let moc = dependencies.tower.storage.backgroundContext
            guard let coreDataNode: Node = await coreDataNode(for: node, context: moc) else { return }
            dependencies.tower.markOfflineAvailable(
                !node.isMarkedOfflineAvailable,
                nodes: [coreDataNode],
                moc: moc
            ) { _ in }
        }
    }

    func trash(node: NodeDTO) {
        trash(nodes: [node])
    }

    private func trash(nodes: [NodeDTO]) {
        dependencies.coordinator.presentTrashAlert(nodes: nodes) { [weak self] in
            Task { [weak self] in
                do {
                    try await self?.sendToTrash(nodes)
                    self?.dependencies.multipleSelectionModel?.setSelectionMode(enabled: false)
                } catch {
                    let ids = nodes.map { $0.id.debugDesc }
                    Log.error("Trash \(ids) failed", error: error, domain: .nodeOperation)
                }
            }
        }
    }

    private func sendToTrash(_ currentNodes: [NodeDTO]) async throws {
        if let performer = dependencies.tower.sdkObjects.nodeOperationPerformer,
           dependencies.tower.featureFlags.isEnabled(flag: .driveiOSSDKTrashNode) {
            try await trash(currentNodes.map(\.id), via: performer)
            return
        }
        let (localNodes, remoteNodes) = currentNodes.partitioned { $0.isLocalFile }

        // Trash local nodes
        let trashingLocalNodes = localNodes.compactMap { (node: NodeDTO) -> TrashingNodeIdentifier? in
            guard let parentID = node.parentID else { return nil }
            let volumeID = node.id.volumeID
            let shareID = node.nodeIdentifier.shareID
            let nodeID = node.id.id
            return TrashingNodeIdentifier(volumeID: volumeID, shareID: shareID, parentID: parentID.id, nodeID: nodeID)
        }

        // Trash remote nodes asynchronously
        let trashingRemoteNodes = remoteNodes.compactMap { (node: NodeDTO) -> TrashingNodeIdentifier? in
            guard let parentID = node.parentID else { return nil }
            let volumeID = node.id.volumeID
            let shareID = node.nodeIdentifier.shareID
            let nodeID = node.id.id
            return TrashingNodeIdentifier(volumeID: volumeID, shareID: shareID, parentID: parentID.id, nodeID: nodeID)
        }

        // Perform local trashing
        try dependencies.tower.trashLocalNode(trashingLocalNodes)
        try await dependencies.tower.trash(trashingRemoteNodes)
    }

    private func trash(_ ids: [AnyVolumeIdentifier], via performer: SDKNodeOperationPerformer) async throws {
        let (affectedIDs, error) = try await performer.trash(nodes: ids).collectCompletion()
        dependencies.tower.sdkObjects.fileDownloader.cancel(operationsOf: affectedIDs)
        if let error { throw error }
    }
}

// MARK: - Handler for bottom action bar in finder view
extension FinderActionHandler: MultipleSelectionActionHandling {
    func handleMultipleSelectionAction(_ action: ActionBarButtonViewModel, nodes: [NodeDTO]) {
        switch action {
        case .trashMultiple:
            trash(nodes: nodes)
        case .moveMultiple:
            dependencies.multipleSelectionModel?.setSelectionMode(enabled: false)
            dependencies.coordinator.presentMoveToFinderBrowser(selectedNodes: nodes)
        case .offlineAvailableMultiple:
            Task.detached { [weak self] in
                guard let self else { return }
                // Only downloadable nodes should be considered for offline available functionality
                // (Proton docs should be excluded)
                let downloadableNodes = nodes.filter { $0.isDownloadable }
                let allMarked = downloadableNodes.allSatisfy { $0.isMarkedOfflineAvailable }
                let context = await dependencies.tower.storage.backgroundContext
                let objects: [Node] = await context.perform { [context] in
                    nodes
                        .map(\.objectID)
                        .compactMap { try? context.typedObject(with: $0) }
                }
                await dependencies.tower.markOfflineAvailable(
                    !allMarked,
                    nodes: objects,
                    moc: context,
                    handler: { _ in }
                )
                await dependencies.multipleSelectionModel?.setSelectionMode(enabled: false)
            }
        case .downloadMultiple:
            let exportableNodes = nodes.filter(\.canExport)
            dependencies.multipleSelectionModel?.setSelectionMode(enabled: false)
            if exportableNodes.isEmpty {
                break
            }
            dependencies.coordinator.presentBatchFileExport(nodes: exportableNodes)
        case .removeMe:
            // remove me only support 1 item
            guard let node = nodes.first else { return }
            removeMe(node: node)
        default: break
        }
    }
}

extension FinderActionHandler: FinderOverlayActionHandling {
    func handleOverlayAction(_ action: ActionBarButtonViewModel) {
        switch action {
        case .cancel:
            dependencies.coordinator.dismiss()
        case .createFolder:
            createFolder()
        default: break
        }
    }
}

extension FinderActionHandler {
    struct Dependencies {
        let bookmarksContainer: BookmarkContainer
        let context: NSManagedObjectContext
        let coordinator: FFinderCoordinator
        let multipleSelectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>?
        let tower: Tower
        let transferManager: FinderTransferManaging
        let userMessageHandler: UserMessageHandlerProtocol

        init(
            bookmarksContainer: BookmarkContainer,
            coordinator: FFinderCoordinator,
            multipleSelectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>?,
            tower: Tower,
            transferManager: FinderTransferManaging,
            userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
        ) {
            self.bookmarksContainer = bookmarksContainer
            self.context = tower.storage.synchronousContextPool.acquire()
            self.coordinator = coordinator
            self.multipleSelectionModel = multipleSelectionModel
            self.tower = tower
            self.transferManager = transferManager
            self.userMessageHandler = userMessageHandler
        }
    }
}
