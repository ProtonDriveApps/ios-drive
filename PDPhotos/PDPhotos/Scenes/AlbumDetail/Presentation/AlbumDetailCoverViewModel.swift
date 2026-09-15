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
import PDCore

final class AlbumDetailCoverViewModel: ObservableObject {
    @Published private(set) var coverData: Data? {
        willSet {
            coverIsChanged.send(())
        }
    }
    @Published private(set) var hasCover: Bool = false
    private let coverIsChanged = PassthroughSubject<Void, Never>()
    private let dependencies: Dependencies
    private var cancellables = Set<AnyCancellable>()
    private var album: Album?
    private var currentPreviewType: PreviewType?
    private var coverID: AnyVolumeIdentifier? {
        guard let album, let linkID = album.coverLinkID else { return nil }
        return .init(id: linkID, volumeID: album.identifier.volumeID)
    }
    private var thumbnailTask: Task<Void, Never>?
    private var readyMetadataIDs = Set<AnyVolumeIdentifier>()
    var coverIsChangedPublisher: AnyPublisher<Void, Never> {
        coverIsChanged.eraseToAnyPublisher()
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        subscribeToUpdate()
    }

    private func subscribeToUpdate() {
        dependencies.albumRepository.updatePublisher
            .sink { [weak self] album in
                guard let self, let album else { return }
                if self.album?.coverLinkID != album.coverLinkID {
                    self.album = album
                    thumbnailTask?.cancel()
                    thumbnailTask = nil
                    readyMetadataIDs.removeAll()
                    loadMetadataIfPossible()
                    loadThumbnailIfNeeded()
                }
                if album.coverLinkID == nil {
                    thumbnailTask?.cancel()
                    thumbnailTask = nil
                    hasCover = false
                    coverData = nil
                } else {
                    hasCover = true
                }
            }
            .store(in: &cancellables)
        dependencies.contentController.content
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.handleFileContentLoad(error: error)
                }
            } receiveValue: { [weak self] content in
                self?.handleFileContentUpdate(content)
            }
            .store(in: &cancellables)
        dependencies.metadataController.readyIDs
            .sink { [weak self] ids in
                guard let self else { return }
                readyMetadataIDs.formUnion(ids)
                loadCoverIfPossible()
            }
            .store(in: &cancellables)
    }

    private func loadThumbnailIfNeeded() {
        guard let coverID else { return }
        if DecryptedFileManager.thumbnailData(id: coverID) != nil {
            reloadImage()
            return
        }
        guard thumbnailTask == nil else { return }
        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await dependencies.thumbnailDownloader?.downloadThumbnail(for: coverID, type: .default)
            } catch {
                Log.error("Failed to download album detail cover thumbnail", error: error, domain: .thumbnails)
            }
            await MainActor.run {
                self.thumbnailTask = nil
                self.reloadImage()
            }
        }
    }

    private func reloadImage() {
        guard
            let coverID,
            let image = DecryptedFileManager.thumbnailData(id: coverID),
            self.coverData != image
        else { return }
        if case .full = currentPreviewType {
            // If the full preview is shown, we don't want to replace it with a thumbnail
            return
        }
        currentPreviewType = .thumbnail
        self.coverData = image
    }

    private func loadMetadataIfPossible() {
        guard let album, let coverID else { return }
        dependencies.metadataController.loadImmediatelly([album.identifier, coverID], forceToRefresh: false)
    }

    private func loadCoverIfPossible() {
        guard let album, let coverID else {
            return
        }
        
        let necessaryIds = [album.identifier, coverID]
        guard readyMetadataIDs.isSuperset(of: necessaryIds) else {
            return
        }
        dependencies.contentController.execute(with: coverID)
    }

    private func handleFileContentUpdate(_ content: FileContent) {
        let mimeType = MimeType(fromFileExtension: content.url.pathExtension)
        if mimeType?.isVideo ?? false { return }
        currentPreviewType = .full
        coverData = try? Data(contentsOf: content.url)
    }

    private func handleFileContentLoad(error: Error) {
        Log.error("Failed to load full album cover preview", error: error, domain: .albums)
        // Fallback to thumbnail
        reloadImage()
    }

    deinit {
        thumbnailTask?.cancel()
        dependencies.contentController.clear()
    }
}

extension AlbumDetailCoverViewModel {
    struct Dependencies {
        let albumRepository: AlbumRepositoryProtocol
        let thumbnailDownloader: SDKThumbnailsDownloaderProtocol?
        let contentController: FileContentController
        let metadataController: MetadataControllerProtocol
    }

    enum PreviewType {
        case thumbnail
        case full
    }
}
