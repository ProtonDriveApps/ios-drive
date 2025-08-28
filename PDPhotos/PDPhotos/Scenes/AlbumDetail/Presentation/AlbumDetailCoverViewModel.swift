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
    private var thumbnailCancellable: AnyCancellable?
    private var thumbnailController: ThumbnailController?
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
                    loadFullCover()
                    loadThumbnailIfNeeded()
                }
                if album.coverLinkID == nil {
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
    }

    private func loadThumbnailIfNeeded() {
        guard let coverID else { return }
        let thumbnailController = dependencies.thumbnailControllerContainer
            .makeSmallThumbnailController(id: coverID)
        self.thumbnailController = thumbnailController

        if thumbnailController.getImage() == nil {
            thumbnailController.bootstrap()
            thumbnailCancellable = thumbnailController.updatePublisher
                .sink { [weak self] _ in
                    self?.reloadImage()
                }
            thumbnailController.load()
        } else {
            reloadImage()
        }
    }

    private func reloadImage() {
        guard
            let image = thumbnailController?.getImage(),
            self.coverData != image
        else { return }
        if case .full = currentPreviewType {
            // If the full preview is shown, we don't want to replace it with a thumbnail
            return
        }
        currentPreviewType = .thumbnail
        self.coverData = image
    }

    private func loadFullCover() {
        guard let coverID else { return }
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
        dependencies.contentController.clear()
    }
}

extension AlbumDetailCoverViewModel {
    struct Dependencies {
        let albumRepository: AlbumRepositoryProtocol
        let thumbnailControllerContainer: ThumbnailsControllersContainerProtocol
        let contentController: FileContentController
    }

    enum PreviewType {
        case thumbnail
        case full
    }
}
