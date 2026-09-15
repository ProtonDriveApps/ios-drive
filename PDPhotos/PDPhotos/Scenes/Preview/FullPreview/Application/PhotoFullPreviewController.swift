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

enum PhotoFullPreview: Equatable {
    case thumbnail(Data)
    case image(URL)
    case video(URL)
    case gif(URL)
    /// PhotoURL, VideoURL, isLoading
    case livePhoto(URL, URL?, Bool)
    /// PhotoURL, childrenURLs, isLoading
    case burstPhoto(URL, [URL], Bool)
}

protocol PhotoFullPreviewController {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    var errorPublisher: AnyPublisher<PhotoFullPreviewError, Never> { get }
    func getPreview() -> PhotoFullPreview?
    func load()
    func clear()
}

enum PhotoFullPreviewError: Error, Equatable, LocalizedError {
    /// Thumbnail is not available
    case noPreviewAvailable
    /// Download file failed
    case fullPreviewNotAvailable(FileContentError)
    
    var errorDescription: String? {
        switch self {
        case .noPreviewAvailable:
            return "No preview available"
        case .fullPreviewNotAvailable(let error):
            return "File is not available \(error)"
        }
    }
}

// Will return full thumbnail for photo or full asset video url.
final class LocalPhotoFullPreviewController: PhotoFullPreviewController {
    private let id: PhotoId
    private let buildType: BuildType
    private let detailController: PhotoPreviewDetailController
    private let photoThumbnailDownloader: SDKThumbnailsDownloaderProtocol
    private let contentController: FileContentController
    private let messageHandler: UserMessageHandlerProtocol
    private let publisher = ObservableObjectPublisher()
    private var fullPreview: PhotoFullPreview?
    private var cancellables = Set<AnyCancellable>()
    private var errorSubject = PassthroughSubject<PhotoFullPreviewError, Never>()
    private var fallbackTask: Task<Void, Never>?

    var updatePublisher: AnyPublisher<Void, Never> {
        publisher.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<PhotoFullPreviewError, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(
        id: PhotoId,
        buildType: BuildType,
        detailController: PhotoPreviewDetailController,
        photoThumbnailDownloader: SDKThumbnailsDownloaderProtocol,
        contentController: FileContentController,
        messageHandler: UserMessageHandlerProtocol
    ) {
        self.id = id
        self.buildType = buildType
        self.detailController = detailController
        self.photoThumbnailDownloader = photoThumbnailDownloader
        self.contentController = contentController
        self.messageHandler = messageHandler
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        let detailPublisher = detailController.photo.setFailureType(to: Error.self)
        Publishers.CombineLatest(detailPublisher, contentController.content)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.handleFullPreviewError(error)
                }
            }, receiveValue: { [weak self] info, content in
                self?.handleReceived(info: info, content: content)
            })
            .store(in: &cancellables)
    }

    private func handleFullPreviewError(_ error: Error) {
        // Pass generic error if no specific is given
        let contentError = FileContentError(error: error)
        errorSubject.send(PhotoFullPreviewError.fullPreviewNotAvailable(contentError))

        // Fallback to thumbnails loading
        loadThumbnailFallback()
    }

    private func loadThumbnailFallback() {
        // Try cached bytes first to avoid an unnecessary download round-trip.
        if let data = cachedThumbnailData() {
            update(with: .thumbnail(data))
            return
        }
        guard fallbackTask == nil else { return }
        fallbackTask = Task { [weak self] in
            guard let self else { return }
            await self.downloadThumbnailFallback()
            await MainActor.run {
                self.fallbackTask = nil
                self.applyThumbnailFallbackResult()
            }
        }
    }

    private func downloadThumbnailFallback() async {
        // Big preview thumbnail first, then fall back to the small one.
        for type in [ThumbnailType.photos, .default] {
            do {
                _ = try await photoThumbnailDownloader.downloadThumbnail(for: id.any(), type: type)
                if DecryptedFileManager.thumbnailData(id: id) != nil {
                    return
                }
            } catch {
                Log.error("Failed to download fallback thumbnail", error: error, domain: .thumbnails, context: LogContext("type: \(type)"))
            }
        }
    }

    private func applyThumbnailFallbackResult() {
        if let data = cachedThumbnailData() {
            update(with: .thumbnail(data))
        } else {
            errorSubject.send(.noPreviewAvailable)
        }
    }

    private func cachedThumbnailData() -> Data? {
        DecryptedFileManager.thumbnailData(id: id, type: .photos) ?? DecryptedFileManager.thumbnailData(id: id, type: .default)
    }

    private func handle(info: PhotoInfo, url: URL) {
        switch info.type {
        case .gif:
            update(with: .gif(url))
        case .photo:
            update(with: .image(url))
        case .video:
            update(with: .video(url))
        }
    }
    
    private func handleReceived(info: PhotoInfo, content: FileContent) {
        if content.couldBeLivePhoto {
            update(with: .livePhoto(content.url, content.childrenURLs.first, content.isLoading))
        } else if content.couldBeBurst {
            update(with: .burstPhoto(content.url, content.childrenURLs, content.isLoading))
        } else {
            handle(info: info, url: content.url)
        }
    }

    private func update(with fullPreview: PhotoFullPreview) {
        if self.fullPreview != fullPreview {
            self.fullPreview = fullPreview
            publisher.send()
        }
    }

    func load() {
        contentController.execute(with: id)
    }

    func getPreview() -> PhotoFullPreview? {
        fullPreview
    }

    func clear() {
        fallbackTask?.cancel()
        fallbackTask = nil
        contentController.clear()
    }
}
