// Copyright (c) 2025 Proton AG
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
import PDUIComponents
import PDLocalization
import PDCoreIOS
import PDCore

class BasePhotosActionViewModel {

    let coordinator: PhotosActionCoordinator
    let selectionController: PhotosSelectionController
    let fileContentController: FileContentController
    let offlineAvailableController: OfflineAvailableController
    let featureFlagsController: FeatureFlagsControllerProtocol
    let metadataController: MetadataControllerProtocol
    let favoritingController: FavoritingControllerProtocol
    let trashDialogFactory: TrashDialogFactoryProtocol
    let userMessageHandler: UserMessageHandlerProtocol

    private var currentSelection: PhotoIdsSet?
    private var fetchedMetadata: PhotoIdsSet = []
    var cancellables = Set<AnyCancellable>()

    // MARK: - State
    @Published var isVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentAction: PhotosAction?
    @Published var actions: PhotosActions = .init(primary: [], more: nil)
    @Published var confirmationRequiringActionModel: DialogSheetModel?

    init(
        coordinator: PhotosActionCoordinator,
        selectionController: PhotosSelectionController,
        fileContentController: FileContentController,
        offlineAvailableController: OfflineAvailableController,
        featureFlagsController: FeatureFlagsControllerProtocol,
        metadataController: MetadataControllerProtocol,
        favoritingController: FavoritingControllerProtocol,
        trashDialogFactory: TrashDialogFactoryProtocol,
        userMessageHandler: UserMessageHandlerProtocol
    ) {
        self.coordinator = coordinator
        self.selectionController = selectionController
        self.fileContentController = fileContentController
        self.offlineAvailableController = offlineAvailableController
        self.featureFlagsController = featureFlagsController
        self.metadataController = metadataController
        self.favoritingController = favoritingController
        self.trashDialogFactory = trashDialogFactory
        self.userMessageHandler = userMessageHandler

        subscribeToUpdates()
        handleSelectionUpdate()
    }

    var type: PhotosActionParentType {
        fatalError("Must override `type`")
    }

    // MARK: - Subscriptions

    private func subscribeToUpdates() {
        selectionController.updatePublisher
            .sink { [weak self] in self?.handleSelectionUpdate() }
            .store(in: &cancellables)

        fileContentController.content
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] content in self?.handleFileUpdate(content) }
            )
            .store(in: &cancellables)

        metadataController.readyIDs
            .filter { [weak self] readyIds in
                guard let selection = self?.currentSelection else { return false }
                return readyIds.isSuperset(of: selection)
            }
            .sink { [weak self] _ in self?.handleMetadataUpdate() }
            .store(in: &cancellables)

        favoritingController.result
            .sink { [weak self] in self?.handleFavoritingUpdate($0) }
            .store(in: &cancellables)
    }

    private func handleSelectionUpdate() {
        let isSelecting = selectionController.isSelecting()
        if !isSelecting {
            fileContentController.clear()
        }

        // The photo gallery is visible from a tabbar, so we need to hide the tabbar during multiple selection for the photos gallery
        if type == .photoGallery {
            coordinator.updateTabBar(isHidden: isSelecting)
        }

        isVisible = isSelecting && !selectionController.getPrimaryIds().isEmpty

        if isVisible {
            // All actions assume we have metadata in our DB. We need to check they're there.
            // Decided to do that check before showing the actual action buttons, so user cannot tap in case
            // we don't have them in DB.
            loadMetadata()
        }
    }

    private func handleFileUpdate(_ content: FileContent?) {
        guard let content else { return }

        if content.couldBeLivePhoto, let videoURL = content.childrenURLs.first {
            coordinator.openNativeShareForLivePhoto(imageURL: content.url, videoURL: videoURL) { [weak self] in
                self?.fileContentController.clear()
            }
        } else if content.couldBeBurst {
            coordinator.openNativeShareForBurstPhoto(urls: [content.url] + content.childrenURLs) { [weak self] in
                self?.fileContentController.clear()
            }
        } else {
            coordinator.openNativeShare(url: content.url) { [weak self] in
                self?.fileContentController.clear()
            }
        }
    }

    private func handleMetadataUpdate() {
        actions = makeActions()
        fetchedMetadata.formUnion(currentSelection ?? [])
        currentSelection = nil
        isLoading = false
    }

    private func handleFavoritingUpdate(_ result: FavoritingResult) {
        switch result {
        case let .failure(error):
            let messageError = PlainMessageError(error.localizedDescription)
            userMessageHandler.handleError(messageError)
        case let .success(output):
            switch output {
            case let .markedFavorite(favoritingOutput):
                var messages = [String]()
                if favoritingOutput.copiedToStream > 0 {
                    messages.append(Localization.favoriting_result_copied(count: favoritingOutput.copiedToStream))
                }
                if favoritingOutput.skipped > 0 {
                    messages.append(Localization.favoriting_result_skipped(count: favoritingOutput.skipped))
                }
                if favoritingOutput.streamPhotos > 0 {
                    messages.append(Localization.favoriting_result_marked(count: favoritingOutput.streamPhotos))
                }
                if !messages.isEmpty {
                    let message = messages.joinedNonEmpty(separator: "\n")
                    userMessageHandler.handleSuccess(message)
                }
            case let .unmarkedFavorite(count):
                userMessageHandler.handleSuccess(Localization.favoriting_result_unmarked(count: count))
            }
        }
    }

    private func loadMetadata() {
        let selection = selectionController.getAllIds()
        let remoteIds = selection.subtracting(fetchedMetadata)
        guard !remoteIds.isEmpty else {
            return
        }

        isLoading = true
        // Subtract already fetched metadata to save bandwidth
        currentSelection = remoteIds
        // Immediate loading guarantees callback when metadata is fetched
        // Callback guarantees correct loading state
        metadataController.loadImmediatelly(Array(remoteIds))
    }

    // MARK: - Actions generation
    func makeActions() -> PhotosActions {
        fatalError("Must override `makeActions`")
    }
    
    func sortActions(_ actions: Set<PhotosAction>) -> PhotosActions {
        let allActions = actions.sorted(by: { $0.rawValue < $1.rawValue })

        if allActions.count > 4 {
            let primary = Array(allActions.prefix(3)) + [.more]
            let more = Array(allActions.dropFirst(3))
            return PhotosActions(primary: primary, more: more)
        } else {
            return PhotosActions(primary: allActions, more: nil)
        }
    }

    // MARK: - Other helpers
    func getSingleId() -> PhotoId? {
        let ids = selectionController.getPrimaryIds()
        return ids.count == 1 ? ids.first : nil
    }
}
