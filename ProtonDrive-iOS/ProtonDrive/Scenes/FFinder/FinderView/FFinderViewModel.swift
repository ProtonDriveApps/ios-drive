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

@preconcurrency import PDCore
import Combine
import CoreData
import Foundation
import PDContacts
import PDCoreIOS
import PDSDKCore
import PDLocalization
import PDUIComponents
import ProtonCoreNetworking

enum FFinderState {
    /// Loading public keys, children list...etc
    case loading
    case ready
}

@MainActor
final class FFinderViewModel: ObservableObject {
    @Published private(set) var activeCellVMs: [FFinderCellViewModel] = []
    @Published private(set) var isLoading = false // Loading from cache
    @Published private(set) var lastUpdated: Date = .distantPast
    @Published private(set) var layout: Layout
    @Published private(set) var isConnectionReachable: Bool
    @Published private(set) var sortPreference: SortPreference
    @Published private(set) var uploadingCellVMs: [FFinderCellViewModel] = []
    @Published private(set) var lockedStateBannerVisibility: LockedStateAlertVisibility = .hidden
    @Published private(set) var upgradeRequirementLevel: UpgradeRequirementLevel = .none

    let dependencies: Dependencies
    let folder: NodeDTO

    private let upgradeRequirementBannerController: UpgradeRequirementBannerControllerProtocol
    var upgradeRequirementHandling: UpgradeRequirementHandling? { upgradeRequirementBannerController }
    var shouldShowVolumeLockBanner: Bool {
        folder.isRoot && scene.currentTab == .files
    }

    private let scrollToTopSubject = PassthroughSubject<Void, Never>()
    private var bottomMoreActionVM: FFinderNodeActionMenuViewModel?
    private var childrenDidUpdateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var latestChildrenUpdateID = 0
    /// Is fetching remote data
    var isFetching: Bool { dependencies.childrenSource.isFetching }
    var isVisible = false
    var isSelecting: Bool { dependencies.multipleSelectionModel?.isSelectionEnabled ?? false }
    var isUploadDisclaimerVisible: Bool { dependencies.scene.isUploadDisclaimerVisible }
    var lastEventFetchedDate: Date? { dependencies.tower.eventSystemLatestFetchTime }
    var scene: any FinderPresenting { dependencies.scene }
    var scrollToTopPublisher: AnyPublisher<Void, Never> { scrollToTopSubject.eraseToAnyPublisher() }
    var tower: Tower { dependencies.tower }

    init(dependencies: Dependencies, folder: NodeDTO) {
        self.dependencies = dependencies
        self.folder = folder
        self.upgradeRequirementBannerController = UpgradeRequirementBannerController(
            appStorePageURL: Constants.appStorePageURL,
            localSettings: dependencies.tower.localSettings
        )
        self.sortPreference = dependencies.tower.localSettings.nodesSortPreference
        self.layout = dependencies.scene.supportsLayoutSwitch ? .init(preference: dependencies.tower.layout) : .list
        self.isConnectionReachable = dependencies.connectionStateResource.currentState.isReachable
        subscribeToUpdates()
    }
    
    deinit {
        childrenDidUpdateTask?.cancel()
    }
    
    private func subscribeToUpdates() {
        dependencies.childrenSource.childrenObserver.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.scheduleChildrenUpdate()
            })
            .store(in: &cancellables)

        dependencies.childrenSource.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.objectWillChange.send()
            })
            .store(in: &cancellables)

        dependencies.multipleSelectionModel?.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        dependencies.tower.localSettings.publisher(for: \.nodesSortPreference)
            .sink { [weak self] sort in
                self?.sortPreferenceDidUpdate(preference: sort)
            }
            .store(in: &cancellables)

        dependencies.tower.sdkObjects.fileUploader.failures
            .sink { [weak self] (_, error) in
                self?.handleUploadError(error)
            }
            .store(in: &cancellables)

        if dependencies.scene.supportsLayoutSwitch {
            dependencies.tower.localSettings.publisher(for: \.nodesLayoutPreference)
                .sink { [weak self] preference in
                    self?.layoutDidUpdate(preference: preference)
                }
                .store(in: &cancellables)
        }

        dependencies.scene.objectWillChange
            .sink(receiveValue: { [weak self] _ in
                self?.objectWillChange.send()
            })
            .store(in: &cancellables)

        dependencies.scrollToTopPublisher
            .sink { [weak self] tappedTab in
                self?.onTap(barItem: tappedTab)
            }
            .store(in: &cancellables)

        dependencies.connectionStateResource.state
            .sink { [weak self] state in
                guard
                    let self,
                    self.isConnectionReachable != state.isReachable
                else { return }
                isConnectionReachable = state.isReachable
                if state.isReachable, isVisible {
                    // Refresh view when device back to online
                    Task { await self.onAppear() }
                }
            }
            .store(in: &cancellables)

        if dependencies.scene.currentTab == .files {
            setupLockedStateBannerVisibility()
            subscribeToLockedStateBannerUpdates()
            upgradeRequirementBannerController
                .subscribeToUpgradeRequirement(currentTab: .files)
                .sink { [weak self] level in
                    self?.upgradeRequirementLevel = level
                }
                .store(in: &cancellables)
        }

        dependencies.childrenSource.start()
    }

    private func setupLockedStateBannerVisibility() {
        if let lockedFlags = dependencies.tower.sessionVault.getUserInfo()?.lockedFlags {
            lockedStateBannerVisibility = LockedStateAlertVisibility(lockedFlags: lockedFlags)
        }
    }

    private func subscribeToLockedStateBannerUpdates() {
        dependencies.tower.sessionVault.userInfoPublisher
            .sink { [weak self] userInfo in
                if let lockedFlags = userInfo.lockedFlags {
                    self?.lockedStateBannerVisibility = LockedStateAlertVisibility(lockedFlags: lockedFlags)
                }
            }
            .store(in: &cancellables)
    }

    func onAppear() async {
        if folder.isSharedWithMeRoot {
            // TODO: finder-refactor
            // Move it to scene

            // Mark volume active so events are triggered more often
            dependencies.volumeIdsController?.setActiveSharedVolume(id: folder.id.volumeID)
        }
        if isFetching { return }
        do {
            try await dependencies.childrenSource.fetchPages()
        } catch {
            handleFetchDataError(error)
        }
    }
    
    func onDisappear() {
        Task {
            await dependencies.childrenSource.cancelRequests()
        }
    }
}

extension FFinderViewModel: HHasRefreshControl {
    func fetchAllChildren() async {
        if isFetching { return }
        do {
            try await dependencies.childrenSource.fetchAllChildren()
        } catch {
            handleFetchDataError(error)
        }
    }
}

// MARK: - Children list
extension FFinderViewModel {
    private func scheduleChildrenUpdate() {
        latestChildrenUpdateID += 1
        let updateID = latestChildrenUpdateID

        isLoading = true
        childrenDidUpdateTask?.cancel()
        childrenDidUpdateTask = Task { [weak self] in
            await self?.childrenDidUpdate(updateID: updateID)
        }
    }

    private func childrenDidUpdate(updateID: Int) async {
        let keysByMail = await fetchPublicKeyIfNeeded()
        defer {
            if updateID == latestChildrenUpdateID {
                isLoading = false
            }
        }
        if Task.isCancelled { return }

        let (activeCellVMs, uploadingCellVMs) = await mappingToCellVM(keysByMail: keysByMail)
        if Task.isCancelled { return }
        if updateID != latestChildrenUpdateID { return }

        self.activeCellVMs = activeCellVMs
        self.uploadingCellVMs = uploadingCellVMs
        let selectable = activeCellVMs.map(\.node.id)
        dependencies.multipleSelectionModel?.update(selectable: Set(selectable))
        updateCacheMetric(cacheCount: activeCellVMs.count)
    }
    
    /// Fetch address's public key
    /// - Returns: [mail: publicKeys]
    private func fetchPublicKeyIfNeeded() async -> [String: [PublicKey]] {
        let context = dependencies.context
        let objectIDs = dependencies.childrenSource.childrenObserver.fetchedObjects.map(\.objectID)
        var signatureEmails = await context.perform { [context] in
            let fetchedObjects: [Node] = objectIDs.compactMap { try? context.typedObject(with: $0) }
            let mails = fetchedObjects.flatMap { node in
                [node.signatureEmail, node.nameSignatureEmail].compactMap { $0 }
            }
            return Array(Set(mails))
        }
        signatureEmails = removeMyAddress(signatureMails: signatureEmails)
        
        return await withTaskGroup(of: (String, [PublicKey]).self) { group in
            for mail in signatureEmails {
                group.addTask {
                    let res = try? await self.dependencies.contactsManager.fetchActivePublicKeys(
                        email: mail,
                        internalOnly: true
                    )
                    return (mail, res?.address.keys.map(\.publicKey) ?? [])
                }
            }
            
            var result: [String: [PublicKey]] = [:]
            
            for await (mail, keys) in group {
                result[mail] = keys
            }
            
            return result
        }
    }
    
    private func removeMyAddress(signatureMails: [String]) -> [String] {
        let addresses = dependencies.tower.sessionVault.allAddresses
        var signatureMails = signatureMails
        for address in addresses {
            if let index = signatureMails.firstIndex(of: address) {
                signatureMails.remove(at: index)
            }
        }
        return signatureMails
    }
    
    private func mappingToCellVM(
        keysByMail: [String: [PublicKey]]
    ) async -> ([FFinderCellViewModel], [FFinderCellViewModel]) {
        let context = dependencies.context
        let objectIDs = dependencies.childrenSource.childrenObserver.fetchedObjects.map(\.objectID)
        let sort = self.sortPreference
        // Resolve nodes in backgroundContext (same as uploads)
        // clearName is transient and per-context
        // so reading from another context can return a stale name after rename.
        let (activeDTOs, uploadingDTOs): ([NodeDTO], [NodeDTO]) = await context.perform { [weak self, context] in
            guard let self else { return ([], []) }
            let fetchedObjects: [Node] = objectIDs.compactMap { try? context.typedObject(with: $0) }
            
            let activeNodes = fetchedObjects
                .filter { $0.state == .active && !$0.isTrashInheriting }
            let activeDTOs = sort.sort(activeNodes)
                .compactMap { self.transform(node: $0, keysByMail: keysByMail) }

            let uploadingNodes = fetchedObjects
                .filter { $0.state?.isUploading ?? false }
            let uploadingDTOs = sort.sort(uploadingNodes)
                .compactMap { self.transform(node: $0, keysByMail: keysByMail) }
            return (activeDTOs, uploadingDTOs)
        }
        let activeCellVMs = activeDTOs.map { transform(node: $0) }
        let uploadingCellVMs = uploadingDTOs.map { transform(node: $0) }
        return (activeCellVMs, uploadingCellVMs)
    }
    
    nonisolated private func transform(node: Node, keysByMail: [String: [PublicKey]]) -> NodeDTO? {
        var keys: [PublicKey] = []
        if let mail = node.nameSignatureEmail ?? node.signatureEmail {
            keys = keysByMail[mail] ?? []
        }
        do {
            return try NodeDTO(node: node, signatureKeys: keys)
        } catch {
            Log.error("Transform NodeDTO failed", error: error, domain: .ui)
            return nil
        }

    }
    
    private func transform(node: NodeDTO) -> FFinderCellViewModel {
        dependencies.scene.makeCellViewModel(for: node)
    }

    private func updateCacheMetric(cacheCount: Int) {
        guard let currentTab = dependencies.scene.currentTab else { return }
        let type: PerformanceMetric.PageType
        switch currentTab {
        case .files: type = .myFiles
        default: return
        }
        dependencies.tower.performanceMetricsController?.updateTab(cacheCount: cacheCount, in: type)
    }
}

// MARK: - Preference
extension FFinderViewModel {
    private func sortPreferenceDidUpdate(preference: SortPreference) {
        if sortPreference == preference { return }
        self.sortPreference = preference
        Task.detached { [weak self] in
            do {
                try await self?.dependencies.childrenSource.resubscribe(sorting: preference)
            } catch {
                await self?.handleFetchDataError(error)
            }
        }
    }
    
    private func layoutDidUpdate(preference: LayoutPreference) {
        let newLayout = Layout(preference: preference)
        if newLayout == layout { return }
        layout = newLayout
    }
    
    func switchSorting(_ sort: SortPreference) {
        dependencies.tower.localSettings.nodesSortPreference = sort
    }
    
    func changeLayout() {
        dependencies.tower.localSettings.nodesLayoutPreference = layout.next.asPreference
    }
    
    func closeUploadDisclaimer() {
        dependencies.tower.localSettings.isUploadingDisclaimerActive = false
    }
}

// MARK: - User actions
extension FFinderViewModel {
    func onLongPressCell() {
        guard dependencies.scene.supportsMultipleSelection else { return }
        dependencies.multipleSelectionModel?.setSelectionMode(enabled: true)
    }
    
    func onTapCell(nodeID: AnyVolumeIdentifier) {
        if dependencies.multipleSelectionModel?.isSelectionEnabled == true {
            dependencies.multipleSelectionModel?.toggle(identifier: nodeID)
        } else {
            guard let cellVM = activeCellVMs.first(where: { $0.node.id == nodeID }) else {
                assertionFailure("Can't find cell vm")
                return
            }
            let node = cellVM.node
            if node.isFolder {
                onTap(folder: node)
            } else if node.isFile {
                onTap(file: node)
            }
        }
    }

    func onTapSubscription() {
        dependencies.coordinator.openSubscriptions()
    }

    func disableSelectionMode() {
        dependencies.multipleSelectionModel?.setSelectionMode(enabled: false)
        bottomMoreActionVM = nil
    }
    
    func toggleSelectAll() {
        dependencies.multipleSelectionModel?.toggleSelectAll()
    }

    func didScrollToBottom() {
        guard dependencies.childrenSource.supportsPaging else { return }
        Task.detached { [weak self] in
            do {
                try await self?.dependencies.childrenSource.fetchNextPage()
            } catch {
                Log.error("Fetch next page failed", error: error, domain: .application)
                await self?.dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
            }
        }
    }

    func applyAction() {
        Task {
            do {
                try await dependencies.scene.applyAction()
                dependencies.coordinator.dismiss()
            } catch {
                dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
            }
        }
    }

    func onTap(barItem: TabBarItem) {
        guard dependencies.scene.currentTab == barItem else { return }
        scrollToTopSubject.send(())
    }
}

// MARK: - Bottom action bar
extension FFinderViewModel {
    func bottomActionMoreButtonVM(node: NodeDTO) -> FFinderNodeActionMenuViewModel {
        let vm = dependencies.viewModelFactory.makeActionMenuViewModel(
            actionHandler: dependencies.actionHandler,
            isSharedWithMeRoot: folder.isSharedWithMeRoot,
            node: node
        )
        bottomMoreActionVM = vm
        return vm
    }

    func handleMultipleSelectionAction(_ action: ActionBarButtonViewModel?) {
        guard let action else { return }
        let nodes = activeCellVMs
            .filter { dependencies.multipleSelectionModel?.selected.contains($0.node.id) ?? false }
            .map(\.node)
        dependencies.actionHandler.handleMultipleSelectionAction(action, nodes: nodes)
    }

    func handleOverlayAction(_ action: ActionBarButtonViewModel?) {
        guard let action else { return }
        dependencies.actionHandler.handleOverlayAction(action)
    }
}

// MARK: - Private functions
extension FFinderViewModel {
    private func handleFetchDataError(_ error: Error) {
        let notExisting = 2501
        if error.bestShotAtReasonableErrorCode == notExisting {
            // The folder is deleted by another clients
            dependencies.coordinator.navigateBack()
            dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
    }

    private func onTap(folder: NodeDTO) {
        if let moveScene = dependencies.scene as? MoveFinderScene {
            dependencies.coordinator.showFolderInMoveToFinderBrowser(
                selectedNodes: moveScene.selectedNodes,
                folder: folder
            )
        } else if dependencies.scene is IIncomingFilesPickerScene {
            dependencies.coordinator.showFolderInIncomingFilesPicker(folder: folder)
        } else if dependencies.scene is FolderFinderScene {
            dependencies.coordinator.showFolder(node: folder)
        }
    }

    private func onTap(file: NodeDTO) {
        if file.isProtonFile {
            dependencies.scene.startRecordingPerformance(id: file.id)
            dependencies.coordinator.openProtonFile(node: file)
        } else if file.isBookmark {
            dependencies.scene.startRecordingPerformance(id: file.id)
            dependencies.coordinator.openBookmark(node: file)
        } else if file.isDownloaded {
            dependencies.scene.startRecordingPerformance(id: file.id)
            dependencies.coordinator.openFilePreview(
                node: file,
                shouldReportPerformance: dependencies.scene.shouldReportPerformance
            )
        } else if file.isDownloadable {
            Task.detached { [weak self] in
                do {
                    try await self?.dependencies.transferManager.download(node: file.id)
                } catch {
                    var message = error.localizedDescription
                    if let sdkError = error as? SDKDownloadErrors, sdkError == .notExisting {
                        message = Localization.error_not_found
                    }
                    await self?.dependencies.userMessageHandler.handleError(PlainMessageError(message))
                }
            }
        }
    }

    private func handleUploadError(_ error: Error) {
        if let uploadError = error as? SDKUploadErrors, uploadError == .noSpaceOnCloud {
            dependencies.coordinator.presentNoSpaceView(storage: .cloud)
        } else {
            let error: Error = (error as? ResponseError)?.underlyingError ?? error
            dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
    }
}

extension FFinderViewModel {
    struct Dependencies {
        let actionHandler: FinderActionHandling
        let childrenSource: FinderChildrenSource
        let contactsManager: ContactsManagerProtocol
        let context: NSManagedObjectContext
        let coordinator: FFinderCoordinator
        let multipleSelectionModel: MMultipleSelectionModel<AnyVolumeIdentifier>?
        let scene: any FinderPresenting
        let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>
        let tower: Tower
        let transferManager: FinderTransferManaging
        let uploadSectionFactory: UploadSectionFactory
        let userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
        let viewModelFactory: FinderViewModelFactory
        let volumeIdsController: SharedVolumeIdsController?
        var connectionStateResource: ConnectionStateResource { tower.connectionStateResource }
    }
}
