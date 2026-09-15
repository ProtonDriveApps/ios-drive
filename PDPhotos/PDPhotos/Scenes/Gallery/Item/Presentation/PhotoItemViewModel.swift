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
import PDCoreIOS

protocol PhotoItemViewModelProtocol: ObservableObject {
    var duration: String? { get }
    var image: Data? { get }
    var isSelecting: Bool { get }
    var isSelected: Bool { get }
    var badges: PhotoItemViewModelBadges? { get }
    func onAppear()
    func onDisappear()
    func didTap()
    func didLongPress()
    func resizeToFit(imageSize: CGSize, in availableSize: CGSize) -> CGSize
}

struct PhotoItemViewModelBadges {
    let shareBadge: PhotoItemShareBadge?
    let isDownloading: Bool
    let isAvailableOffline: Bool
    /// Number of children photos in burst photo
    /// nil means the given photo is not a burst
    let burstChildrenCount: Int?
    let isFavorite: Bool

    var isEmpty: Bool {
        shareBadge == nil && !isDownloading && !isAvailableOffline && burstChildrenCount == nil && !isFavorite
    }
}

enum PhotoItemShareBadge {
    case link
    case collaborative
}

final class PhotoItemViewModel: PhotoItemViewModelProtocol {
    private var item: PhotoGridViewItem
    private let thumbnailDownloader: SDKThumbnailsDownloaderProtocol
    private let coordinator: PhotoItemCoordinator
    private let selectionController: PhotosSelectionController
    private let infoController: PhotoAdditionalInfoController
    private let durationFormatter: DurationFormatter
    private let debounceResource: DebounceResource
    private let fetchingController: PhotosListFetchingControllerProtocol
    private let metadataController: MetadataControllerProtocol
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let thumbnailCache: ThumbnailURLCache
    private var thumbnailTask: Task<Void, Never>?
    private var selectionCancellable: AnyCancellable?
    private var isVisible = false

    private var id: PhotoId {
        item.id
    }
    private var listingId: PhotoListingId {
        PhotoListingId(primary: id, secondary: item.secondaryIds.map { PhotoId(id: $0, volumeID: item.volumeId) })
    }

    @Published var duration: String?
    var image: Data?
    @Published var isSelecting = false
    @Published var isSelected = false
    var badges: PhotoItemViewModelBadges?

    init(item: PhotoGridViewItem, thumbnailDownloader: SDKThumbnailsDownloaderProtocol, coordinator: PhotoItemCoordinator, selectionController: PhotosSelectionController, infoController: PhotoAdditionalInfoController, durationFormatter: DurationFormatter, debounceResource: DebounceResource, fetchingController: PhotosListFetchingControllerProtocol, featureFlagsController: FeatureFlagsControllerProtocol, metadataController: MetadataControllerProtocol, thumbnailCache: ThumbnailURLCache) {
        self.item = item
        self.thumbnailDownloader = thumbnailDownloader
        self.coordinator = coordinator
        self.selectionController = selectionController
        self.infoController = infoController
        self.durationFormatter = durationFormatter
        self.debounceResource = debounceResource
        self.fetchingController = fetchingController
        self.metadataController = metadataController
        self.featureFlagsController = featureFlagsController
        self.thumbnailCache = thumbnailCache
        setUpAfterInitialization()
    }

    private func makeBadges() -> PhotoItemViewModelBadges? {
        guard let metadata = item.metadata else {
            return nil
        }

        let shareBadge: PhotoItemShareBadge?
        if metadata.hasDirectShare && featureFlagsController.hasSharing {
            shareBadge = .collaborative
        } else if metadata.isShared {
            shareBadge = .link
        } else {
            shareBadge = nil
        }
        let badges = PhotoItemViewModelBadges(
            shareBadge: shareBadge,
            isDownloading: !metadata.isAvailableOffline && metadata.isDownloading,
            isAvailableOffline: metadata.isAvailableOffline,
            burstChildrenCount: metadata.burstChildrenCount,
            isFavorite: metadata.isFavorite
        )

        guard !badges.isEmpty else {
            return nil
        }

        return badges
    }

    private func setUpAfterInitialization() {
        badges = makeBadges()
        reloadImage()
        reloadSelection()
        reloadDurationIfNeeded()
    }

    func setItem(_ item: PhotoGridViewItem) {
        // Should be used when item is updated (metadata) to avoid costly reinitialization of the viewModel
        guard item != self.item else {
            return
        }
        self.item = item
        setUpAfterInitialization()
        if isVisible {
            loadContent()
        }
    }

    func onAppear() {
        isVisible = true
        reloadImage()
        reloadSelection()
        fetchingController.loadNextIfNeeded(captureTime: item.captureTime)

        debounceResource.debounce(interval: 0.2) { [weak self] in
            self?.loadContent()
        }

        selectionCancellable = selectionController.updatePublisher
            .sink { [weak self] in
                self?.reloadSelection()
            }
    }

    func onDisappear() {
        if isVisible {
            cleanUp()
            isVisible = false
        }
    }

    private func cleanUp() {
        guard isVisible else {
            return
        }
        image = nil
        debounceResource.cancel()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        metadataController.cancel(identifier: id)
        selectionCancellable = nil
    }

    private func reloadDurationIfNeeded() {
        guard let metadata = item.metadata, metadata.isVideo else {
            return
        }

        guard let duration = infoController.getInfo()?.duration else {
            return
        }

        self.duration = durationFormatter.formatDuration(from: duration)
    }

    private func loadContent() {
        guard let metadata = item.metadata else {
            let ids = [id] + item.secondaryIds.map { AnyVolumeIdentifier(id: $0, volumeID: id.volumeID) }
            metadataController.loadOpportunistically(ids)
            return
        }

        if metadata.isVideo {
            infoController.subscribeToUpdates()
            infoController.load()
            infoController.info
                .compactMap { [weak self] info in
                    if let duration = info.duration {
                        return self?.durationFormatter.formatDuration(from: duration)
                    } else {
                        return ""
                    }
                }
                .assign(to: &$duration)
        }

        loadThumbnailIfNeeded()
    }

    private func loadThumbnailIfNeeded() {
        if let cachedImage = thumbnailCache.getThumbnailData(id: id) {
            updateImage(cachedImage)
            return
        }
        guard thumbnailTask == nil else { return }
        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await thumbnailDownloader.downloadThumbnail(for: id.any(), type: .default)
            } catch {
                Log.error("Failed to download photo thumbnail", error: error, domain: .thumbnails)
            }
            await MainActor.run {
                self.thumbnailTask = nil
                self.reloadImage()
            }
        }
    }

    private func reloadImage() {
        let image = thumbnailCache.getThumbnailData(id: id)
        updateImage(image)
    }

    private func updateImage(_ image: Data?) {
        if self.image != image {
            self.image = image
            // We don't want to make image @Published because we also want to deallocate it when onDisappear without triggering view updates.
            // So we need to trigger update here.
            objectWillChange.send()
        }
    }

    func didTap() {
        if selectionController.isSelecting() {
            selectionController.toggle(id: listingId)
        } else {
            let albumId = item.albumId.map { AlbumIdentifier(id: $0, volumeID: id.volumeID) }
            coordinator.openPreview(id: id, albumId: albumId)
        }
    }

    func didLongPress() {
        if selectionController.isSelecting() {
            selectionController.toggle(id: listingId)
        } else {
            selectionController.start(selectedID: [listingId])
        }
    }

    private func reloadSelection() {
        isSelecting = selectionController.isSelecting()
        isSelected = selectionController.getPrimaryIds().contains(id)
    }

    func resizeToFit(imageSize: CGSize, in availableSize: CGSize) -> CGSize {
        let widthRatio  = availableSize.width / imageSize.width
        let heightRatio = availableSize.height / imageSize.height

        let scaleFactor = min(widthRatio, heightRatio)

        let resizedWidth  = imageSize.width * scaleFactor
        let resizedHeight = imageSize.height * scaleFactor
        return CGSize(width: resizedWidth, height: resizedHeight)
    }

    deinit {
        cleanUp()
    }
}
