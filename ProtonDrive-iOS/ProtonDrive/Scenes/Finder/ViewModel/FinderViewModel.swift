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

import SwiftUI
import UIKit
import Combine
import PDCore
import PDCoreIOS
import PDUIComponents
import ProtonCoreNetworking
import ProtonCoreDataModel

typealias ListState = TrashViewModel.ListState
typealias ObservableFinderViewModel = FinderViewModel & ObservableObject

protocol NodeEditionViewModel: BookmarManagingViewModel {
    var isSharedWithMeRoot: Bool { get }
    func setFavorite(_ favorite: Bool, nodes: [Node])
    func markOfflineAvailable(_ mark: Bool, nodes: [Node])
    func sendToTrash(_ currentNodes: [Node], completion: @escaping (Result<Void, Error>) -> Void)
    func removeMe(_ currentNode: Node, completion: @escaping (Result<Void, Error>) -> Void)
    func sendError(_ error: Error)
}

protocol BookmarManagingViewModel {
    func removeBookmark(_ bookmark: CoreDataBookmark)
    func copyBookmarkUrl(_ bookmark: CoreDataBookmark)
}

extension BookmarManagingViewModel {
    func copyBookmarkUrl(_ bookmark: PDCore.CoreDataBookmark) { }
    func removeBookmark(_ bookmark: CoreDataBookmark) { }
}

struct NodeWrapper: Identifiable, Equatable {
    let id: String
    let node: Node

    init(_ node: Node) {
        self.id = node.id
        self.node = node
    }
}

protocol FinderViewModel: NodeEditionViewModel, ScrollToTopViewModel {
    associatedtype Model: FinderModel, NodesListing
    typealias ApplyActionCompletion = () -> Void
    var model: Model { get }
    var provedEmpty: Bool { get }
    var currentTab: TabBarItem? { get }

    var sorting: SortPreference { get }
    var supportsSortingSwitch: Bool { get }
    var permanentChildrenSectionTitle: String { get }
    func subscribeToSort()

    var layout: Layout { get }
    var supportsLayoutSwitch: Bool { get }
    func changeLayout()

    var childrenCancellable: AnyCancellable? { get set }
    var transientChildren: [NodeWrapper] { get set }
    var permanentChildren: [NodeWrapper] { get set }
    var upgradeRequirementLevel: UpgradeRequirementLevel { get }
    var upgradeRequirementHandling: UpgradeRequirementHandling? { get }

    var isVisible: Bool { get set }
    var isRoot: Bool { get }
    var genericErrors: ErrorRegulator { get }

    var isSharedWithMeRoot: Bool { get }
    var hasPlusFunctionality: Bool { get }

    var nodeName: String { get }
    var isUpdating: Bool { get set }
    var trailingNavBarItems: [NavigationBarButton] { get }
    var leadingNavBarItems: [NavigationBarButton] { get }
    var lastUpdated: Date { get }
    var featureFlagsController: FeatureFlagsControllerProtocol { get }

    func refreshOnAppear()
    func didScrollToBottom()

    func selected(file: File)
    func childViewModel(for node: Node) -> NodeCellConfiguration
    func applyAction(completion: @escaping ApplyActionCompletion)

    var isUploadDisclaimerVisible: Bool { get }
    var lockedStateCancellable: AnyCancellable? { get set }
    var lockedStateBannerVisibility: LockedStateAlertVisibility { get set }
    func reportListIsShown()
    func closeUploadDisclaimer()
}

extension FinderViewModel {
    var isSharedWithMeRoot: Bool {
        return false
    }

    var node: Folder? {
        self.model.folder
    }

    var upgradeRequirementLevel: UpgradeRequirementLevel { .none }
    var upgradeRequirementHandling: UpgradeRequirementHandling? { nil }

    var lockedFlags: LockedFlags? {
        return self.model.tower.sessionVault.getUserInfo()?.lockedFlags
    }

    func subscribeToChildren() {
        self.childrenCancellable?.cancel()
        self.childrenCancellable = self.model.children()
            .filter { [weak self] _, _ in
                // reordering is heavy operation, so we do not want to perform it on all the folders at once when the app-wide setting is changed
                // instead we will call refreshOnAppear() when the view is back visible
                self?.isVisible == true
            }
            .removeDuplicates(by: { previous, current in
                return previous.0 == current.0 && previous.1 == current.1
            })
            .sink { [weak self] activeSorted, uploading in
                guard let self = self, self.isVisible else { return }
                self.model.tower.performanceMetricsController?.updateTab(cacheCount: activeSorted.count, in: .myFiles)
                self.permanentChildren = activeSorted.map(NodeWrapper.init)
                self.transientChildren = uploading.map(NodeWrapper.init)
            }
    }

    func switchSorting(_ newValue: SortPreference) {
        self.model.switchSorting(newValue)
    }

    var noChildren: Bool {
        permanentChildren.isEmpty && transientChildren.isEmpty
    }

    var provedChildrenCount: Bool {
        lastUpdated > .distantPast && !isUpdating
    }

    var provedEmpty: Bool {
        noChildren && provedChildrenCount
    }

    var needsNoConnectionBackground: Bool {
        guard model is NodesFetching, isVisible else {
            return false
        }

        return noChildren && !provedChildrenCount
    }

    var emptyBackgroundConfig: PlaceholderViewConfiguration? {
        guard provedEmpty else { return nil }

        switch self.model {
        case is NodesFetching:
            if self is ComputerRootFolderViewModel {
                return .emptyComputerRootFolder
            }

            if hasPlusFunctionality {
                return .folder
            } else {
                return .folderWithoutMessage
            }
        case is SharedModel:
            return .shared
        case is SharedByMeModel:
            return .sharedByMe
        case is OfflineAvailableModel:
            return .offlineAvailable
        case is SharedWithMeModel:
            return .sharedWithMe
        default:
            return nil
        }
    }

    var isUploadDisclaimerVisible: Bool { false }

    func closeUploadDisclaimer() {}
}

typealias FinderViewModelWithSelection = any FinderViewModel & HasMultipleSelection
extension FinderViewModel where Self: HasMultipleSelection {

    func actionBarAction(_ tapped: ActionBarButtonViewModel?, sheet: Binding<FinderCoordinator.Destination?>, menuItem: Binding<FinderMenu?>) {
        let nodes = selectedNodes()

        switch tapped {
        case .trashMultiple:
            let vm = NodeRowActionMultipleMenuViewModel(nodes: nodes.map(\.node), model: self)
            menuItem.wrappedValue = .trash(vm: vm, isNavigationMenu: false)

        case .moveMultiple where !nodes.isEmpty:
            sheet.wrappedValue = .move(nodes.map(\.node), parent: self.node ?? nodes.map(\.node).first!.parentLink)

        case .offlineAvailableMultiple:
            // Only downloadable nodes should be considered for offline available functionality
            // (Proton docs should be excluded)
            let nodes = nodes.filter { $0.node.isDownloadable }
            self.markOfflineAvailable(!nodes.map(\.node).allSatisfy(\.isMarkedOfflineAvailable), nodes: nodes.map(\.node))
        case .removeMe:
            let vm = NodeRowActionMultipleMenuViewModel(nodes: nodes.map(\.node), model: self)
            menuItem.wrappedValue = .removeMe(vm: vm)
        default: break
        }
    }

    func selectedNodes() -> [NodeWrapper] {
        permanentChildren.filter { selection.selected.contains($0.node.identifier) }
    }
}

extension FinderViewModel where Self: UploadingViewModel, Self: DownloadingViewModel, Self: HasMultipleSelection {
    func childViewModel(for node: Node) -> NodeCellConfiguration {
        NodeCellWithProgressConfiguration(
            from: node,
            // selection should not be available for uploading files
            selectionModel: node.state?.existsOnCloud == true ? self.prepareSelectionModel() : nil,
            // progresses come from Uploader a little later that nodes from db. Waiting for notification to redraw.
            progressesAvailable: hasReceivedUploadsUpdate,
            thumbnailLoader: self.model.tower.sdkObjects.thumbnailDownloader,
            nodeStatePolicy: nodeStatePolicy,
            featureFlagsController: featureFlagsController,
            isSharedWithMeRoot: isSharedWithMeRoot,
            progressTrackersController: progressTrackersController,
            nodeDownloadedResource: nodeDownloadedResource
        )
    }

    func isUploadFailed(node: Node) -> Bool {
        guard let file = node as? File else {
            return false
        }
        guard let uploadId = file.uploadID?.uuidString else {
            return false
        }
        let progressTracker = progressTrackersController.getUploadProgress(for: uploadId)
        let areProgressesAvailable = hasReceivedUploadsUpdate
        return nodeStatePolicy.isUploadFailed(for: node, progressTracker: progressTracker, areProgressesAvailable: areProgressesAvailable)
    }
}

extension FinderViewModel where Self: DownloadingViewModel, Self: HasMultipleSelection {
    func childViewModel(for node: Node) -> NodeCellConfiguration {
        NodeCellWithProgressConfiguration(
            from: node,
            selectionModel: self.prepareSelectionModel(),
            thumbnailLoader: self.model.tower.sdkObjects.thumbnailDownloader,
            nodeStatePolicy: DisabledNodeStatePolicy(),
            featureFlagsController: featureFlagsController,
            isSharedWithMeRoot: isSharedWithMeRoot,
            progressTrackersController: progressTrackersController,
            nodeDownloadedResource: nodeDownloadedResource
        )
    }
}

extension FinderViewModel where Self: UploadingViewModel, Self.Model: UploadsListing {

    func subscribeToChildrenUploading() {
        Task { @MainActor in
            self.childrenUploadCancellable?.cancel()
            self.childrenUploadCancellable = self.model.childrenUploading()
                .catch {  [weak self] error -> Empty<([File], [UUID: Progress]), Error> in
                    switch error {

                    case let error where error is CloudSlot.Errors:
                        self?.genericErrors.send(error)

                    case let error where error is ValidationError<String>:
                        self?.genericErrors.send(error)

                    case let error as NSError where FinderError(error) == .noSpaceOnCloud:
                        self?.genericErrors.send(error)
                        fallthrough

                    default:
                        self?.uploadErrors.send(error)
                    }

                    return .init()
                }
                .sink(receiveCompletion: { [weak self] _ in
                    self?.subscribeToChildrenUploading()
                }, receiveValue: { [weak self] files, progress in
                    let trackersValues = progress.map { key, value in
                        return (key.uuidString, ProgressTracker(progress: value, direction: .upstream))
                    }
                    let trackersDictionary = Dictionary(uniqueKeysWithValues: trackersValues)
                    self?.progressTrackersController.setUploads(progresses: trackersDictionary)
                    if self?.hasReceivedUploadsUpdate == false {
                        self?.hasReceivedUploadsUpdate = true
                    }
                })
        }
    }

    func subscribeToSDKNotify() {
        Task { @MainActor in
            let uploader = model.tower.sdkObjects.fileUploader
            uploader.failures
                .sink { [weak self] info in
                    self?.genericErrors.send(info.1)
                }
                .store(in: &cancellables)
        }
    }
}

extension FinderViewModel where Self: DownloadingViewModel, Self.Model: DownloadsListing {
    func subscribeToChildrenDownloading() {
        Task { @MainActor in
            self.subscribeToChildrenDownloadingAsync()
        }
    }

    @MainActor private func subscribeToChildrenDownloadingAsync() {
        self.childrenDownloadCancellable?.cancel()
        self.childrenDownloadCancellable = self.model.childrenDownloading()
            .receive(on: DispatchQueue.main)
            .catch { [weak self] error -> Empty<ProgressTrackers, Error> in
                let error: Error = (error as? ResponseError)?.underlyingError ?? error
                self?.genericErrors.send(error)
                return .init()
            }
            .sink(receiveCompletion: { [weak self] _ in
                self?.subscribeToChildrenDownloading()
            }, receiveValue: { [weak self] progresses in
                // This only sets data to controller so only relevant subviews can subscribe and reload
                self?.progressTrackersController.setDownloads(progresses: progresses)
            })
    }

    func selected(file: File) {
        downloadFile(file: file)
    }
}

extension FinderViewModel where Self.Model: NodesListing {

    func download(node: Node) {
        guard let file = node as? File,
              file.activeRevisionDraft == nil else { return }

        guard node.state != .uploading else {
            Log.error(error: DriveError(DriveFinderUpload()), domain: .application)
            return
        }

        downloadFile(file: file)
    }

    private func downloadFile(file: File) {
        guard let downloadsListing = self.model as? DownloadsListing else {
            return
        }
        downloadsListing.download(node: file)
    }

    func setFavorite(_ favorite: Bool, nodes: [Node]) {
        model.tower.setFavourite(favorite, nodes: nodes, moc: model.tower.storage.backgroundContext) { _ in }
    }

    func markOfflineAvailable(_ mark: Bool, nodes: [Node]) {
        model.tower.markOfflineAvailable(mark, nodes: nodes, moc: model.tower.storage.backgroundContext) { _ in }
    }

    func removeMe(_ currentNode: Node, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let moc = currentNode.moc else {
            completion(.failure(Node.noMOC()))
            return
        }

        guard let share = currentNode.directShares.first else {
            completion(.failure(currentNode.invalidState("Shared Node should have a direct share")))
            return
        }

        guard let memberID = share.members.first?.id else {
            completion(.failure(currentNode.invalidState("Shared Node should have a memberID")))
            return
        }

        let shareID = share.id

        Task {
            do {
                try await model.tower.removeMember(shareID: shareID, memberID: memberID)
                try await moc.perform {
                    if let folder = currentNode as? Folder {
                        folder.isolateChildrenToPreventCascadeDeletion()
                    }
                    moc.delete(currentNode)
                    moc.delete(share)
                    try moc.saveOrRollback()
                    completion(.success)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    @MainActor
    func sendToTrash(_ currentNodes: [Node], completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await sendToTrash(currentNodes)
                completion(.success)
            } catch {
                completion(.failure(error))
            }
        }
    }

    func sendToTrash(_ currentNodes: [Node]) async throws {
        if let performer = model.tower.sdkObjects.nodeOperationPerformer,
           model.tower.featureFlags.isEnabled(flag: .driveiOSSDKTrashNode) {
            try await trash(currentNodes, via: performer)
            return
        }
        guard let moc = currentNodes.first?.moc else {
            throw Node.noMOC()
        }

        let (trashingLocalNodes, trashingRemoteNodes) = try await moc.perform { [weak self] in
            if self == nil { throw DriveError("FinderViewModel was deallocated before it could trash items") }

            let (localNodes, remoteNodes) = currentNodes.partitioned { $0.isLocalFile }

            // Trash local nodes
            let trashingLocalNodes = localNodes.compactMap { (node: Node) -> TrashingNodeIdentifier? in
                guard let parent = node.parentNode else { return nil }
                return TrashingNodeIdentifier(volumeID: node.volumeID, shareID: node.shareId, parentID: parent.id, nodeID: node.id)
            }

            // Trash remote nodes asynchronously
            let trashingRemoteNodes = remoteNodes.compactMap { (node: Node) -> TrashingNodeIdentifier? in
                guard let parent = node.parentNode else { return nil }
                return TrashingNodeIdentifier(volumeID: node.volumeID, shareID: node.shareId, parentID: parent.id, nodeID: node.id)
            }

            return (trashingLocalNodes, trashingRemoteNodes)
        }

        // Perform local trashing
        try model.tower.trashLocalNode(trashingLocalNodes)
        try await model.tower.trash(trashingRemoteNodes)
    }

    func sendError(_ error: Error) {
        let error: Error = (error as? ResponseError)?.underlyingError ?? error
        genericErrors.send(error)
    }

    private func trash(_ currentNodes: [Node], via performer: SDKNodeOperationPerformer) async throws {
        let ids = currentNodes.map { $0.identifier.any() }
        let (affectedIDs, error) = try await performer.trash(nodes: ids).collectCompletion()
        model.tower.sdkObjects.fileDownloader.cancel(operationsOf: affectedIDs)
        if let error { throw error }
    }
}

extension FinderViewModel {
    func setupLockedStateBannerVisibility() {
        if let lockedFlags {
            self.lockedStateBannerVisibility = LockedStateAlertVisibility(lockedFlags: lockedFlags)
        }
    }

    func subscribeToUserInfoUpdates() {
        lockedStateCancellable?.cancel()
        lockedStateCancellable = self.model.tower.sessionVault.userInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userInfo in
                if let lockedFlags = userInfo.lockedFlags {
                    self?.lockedStateBannerVisibility = LockedStateAlertVisibility(lockedFlags: lockedFlags)
                }
            }
    }
}

struct DriveFinderUpload: Error {

    var localizedDescription: String {
        "Uploading file with no activeRevisionDraft"
    }
}

extension FinderViewModel {
    func startRecordingPerformance(node: Node) {
        guard let file = node as? File else {
            return
        }
        guard let controller = model.tower.performanceMetricsController else {
            assert(false)
            return
        }
        guard let type = currentTab?.toMetricTag else {
            return
        }
        controller.startRecord(id: file.identifier.any(), pageType: type)
    }
}
