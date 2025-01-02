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
import PDCore

protocol PhotoItemViewModelProtocol: ObservableObject {
    var duration: String? { get }
    var image: Data? { get }
    var isSelecting: Bool { get }
    var isSelected: Bool { get }
    var shareBadge: PhotoItemShareBadge? { get }
    var isDownloading: Bool { get }
    var isAvailableOffline: Bool { get }
    /// Number of children photos in burst photo
    /// nil means the given photo is not a burst
    var burstChildrenCount: Int? { get }
    func onAppear()
    func onDisappear()
    func didTap()
    func didLongPress()
}

struct PhotoItemViewModelData {
    let image: Data?
    let duration: String?
}

enum PhotoItemShareBadge {
    case link
    case collaborative
}

final class PhotoItemViewModel: PhotoItemViewModelProtocol {
    private let id: PhotoId
    private let item: PhotoGridViewItem
    private let thumbnailController: ThumbnailController
    private let coordinator: PhotoItemCoordinator
    private let selectionController: PhotosSelectionController
    private let infoController: PhotoAdditionalInfoController
    private let durationFormatter: DurationFormatter
    private let debounceResource: DebounceResource
    private let loadController: PhotosPagingLoadController
    private var thumbnailCancellable: AnyCancellable?
    private var selectionCancellable: AnyCancellable?

    @Published var duration: String?
    var image: Data?
    @Published var isSelecting = false
    @Published var isSelected = false
    let isDownloading: Bool
    let isAvailableOffline: Bool
    let shareBadge: PhotoItemShareBadge?
    let burstChildrenCount: Int?

    init(item: PhotoGridViewItem, thumbnailController: ThumbnailController, coordinator: PhotoItemCoordinator, selectionController: PhotosSelectionController, infoController: PhotoAdditionalInfoController, durationFormatter: DurationFormatter, debounceResource: DebounceResource, loadController: PhotosPagingLoadController, featureFlagsController: FeatureFlagsControllerProtocol) {
        id = PhotoId(item.photoId, item.shareId, item.volumeId)
        self.item = item
        self.thumbnailController = thumbnailController
        self.coordinator = coordinator
        self.selectionController = selectionController
        self.infoController = infoController
        self.durationFormatter = durationFormatter
        self.debounceResource = debounceResource
        self.loadController = loadController

        if item.hasDirectShare && featureFlagsController.hasSharing {
            shareBadge = .collaborative
        } else if item.isShared {
            shareBadge = .link
        } else {
            shareBadge = nil
        }
        isDownloading = !item.isAvailableOffline && item.isDownloading
        isAvailableOffline = item.isAvailableOffline
        burstChildrenCount = item.burstChildrenCount
        reloadImage()
        reloadSelection()
        debounceResource.debounce(interval: 1) { [weak self] in
            self?.onAppear()
        }
    }

    func onAppear() {
        reloadImage()
        reloadSelection()
        loadController.loadNextIfNeeded(captureTime: item.captureTime)

        debounceResource.debounce(interval: 0.2) { [weak self] in
            self?.loadContent()
        }

        selectionCancellable = selectionController.updatePublisher
            .sink { [weak self] in
                self?.reloadSelection()
            }
    }

    func onDisappear() {
        cleanUp()
    }

    private func cleanUp() {
        image = nil
        debounceResource.cancel()
        thumbnailController.cancel()
        thumbnailCancellable = nil
        selectionCancellable = nil
    }

    private func loadContent() {
        if item.isVideo {
            infoController.subscribeToUpdates()
            infoController.load()
            infoController.info
                .compactMap { [weak self] info in
                    if let duration = info.duration {
                        return self?.durationFormatter.formatDuration(from: duration)
                    } else {
                        return nil
                    }
                }
                .assign(to: &$duration)
        }

        thumbnailController.bootstrap()
        thumbnailCancellable = thumbnailController.updatePublisher
            .sink { [weak self] _ in
                self?.reloadImage()
            }
        if thumbnailController.getImage() == nil {
            thumbnailController.load()
        }
    }

    private func reloadImage() {
        let image = thumbnailController.getImage()
        if self.image != image {
            self.image = image
            // We don't want to make image @Published because we also want to deallocate it when onDisappear without triggering view updates.
            // So we need to trigger update here.
            objectWillChange.send()
        }
    }

    func didTap() {
        if selectionController.isSelecting() {
            selectionController.toggle(id: id)
        } else {
            coordinator.openPreview(with: id)
        }
    }

    func didLongPress() {
        selectionController.start()
    }

    private func reloadSelection() {
        isSelecting = selectionController.isSelecting()
        isSelected = selectionController.getIds().contains(id)
    }

    deinit {
        cleanUp()
    }
}
