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
import PDLocalization
import PDCore

final class AlbumGridItemViewModel: GridViewItem, ObservableObject {
    @Published private(set) var title: String = ""
    @Published private(set) var fullDescription: String = ""
    @Published private(set) var albumType: String?
    @Published private(set) var photoCount: Int = 0

    let id: AnyVolumeIdentifier
    private let debounceResource: DebounceResource
    private let metadataController: MetadataControllerProtocol
    private let thumbnailDownloader: SDKThumbnailsDownloaderProtocol?
    private let thumbnailCache: ThumbnailURLCache
    private var albumRepository: AlbumRepositoryProtocol
    private var cancellable: AnyCancellable?
    private var coverLinkID: String?
    private var isAppearing = false
    private var thumbnailTask: Task<Void, Never>?
    private(set) var image: Data?

    public init(
        albumID: AnyVolumeIdentifier,
        albumRepository: AlbumRepositoryProtocol,
        debounceResource: DebounceResource,
        metadataController: MetadataControllerProtocol,
        thumbnailDownloader: SDKThumbnailsDownloaderProtocol?,
        thumbnailCache: ThumbnailURLCache
    ) {
        self.albumRepository = albumRepository
        self.id = albumID
        self.debounceResource = debounceResource
        self.metadataController = metadataController
        self.thumbnailDownloader = thumbnailDownloader
        self.thumbnailCache = thumbnailCache

        subscribeToUpdate()
    }

    func subscribeToUpdate() {
        albumRepository.start()
        cancellable = albumRepository.updatePublisher
            .sink(receiveValue: { [weak self] album in
                guard let self, let album else { return }
                handleAlbumUpdate(album: album)
            })
    }

    private func handleAlbumUpdate(album: Album) {
        title = album.clearName ?? ""
        photoCount = album.photoCount

        let items = Localization.item_plural_type_with_num(num: Int(album.photoCount)).lowercased()
        if album.shareID == nil {
            fullDescription = items
        } else {
            let shared = Localization.file_detail_shared
            fullDescription = "\(items) ⋅ \(shared)"
        }

        if album.shareID != nil {
            switch album.role {
            case .viewer, .editor, .admin:
                albumType = Localization.album_type_shared_with_me
            case .owner:
                albumType = Localization.album_type_shared_by_me
            }
        } else {
            albumType = nil
        }

        guard coverLinkID != album.coverLinkID else { return }
        coverLinkID = album.coverLinkID
        image = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
        guard coverLinkID != nil else {
            objectWillChange.send()
            return
        }
        if isAppearing {
            reloadImage()
            loadThumbnailIfNeeded()
        }
    }

    func onAppear() {
        isAppearing = true
        reloadImage()
        debounceResource.debounce(interval: 0.2) { [weak self] in
            guard let self else { return }
            self.loadContent()
        }
    }

    func onDisappear() {
        isAppearing = false
        image = nil
        debounceResource.cancel()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        metadataController.cancel(identifier: id)
    }

    private func loadContent() {
        reloadImage()
        loadThumbnailIfNeeded()
        metadataController.loadOpportunistically([id])
    }

    private func loadThumbnailIfNeeded() {
        guard image == nil, let coverLinkID else { return }
        let photoID = PhotoId(id: coverLinkID, volumeID: id.volumeID)
        if let cachedImage = thumbnailCache.getThumbnailData(id: photoID) {
            image = cachedImage
            objectWillChange.send()
            return
        }
        guard thumbnailTask == nil else { return }
        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await thumbnailDownloader?.downloadThumbnail(for: photoID.any(), type: .default)
            } catch {
                Log.error("Failed to download album cover thumbnail", error: error, domain: .thumbnails)
            }
            await MainActor.run {
                self.thumbnailTask = nil
                self.reloadImage()
            }
        }
    }

    private func reloadImage() {
        guard
            let coverLinkID,
            let image = thumbnailCache.getThumbnailData(id: PhotoId(id: coverLinkID, volumeID: id.volumeID)),
            self.image != image
        else { return }
        self.image = image
        // We don't want to make image @Published because we also want to deallocate it when onDisappear without triggering view updates.
        // So we need to trigger update here.
        objectWillChange.send()
    }
}
