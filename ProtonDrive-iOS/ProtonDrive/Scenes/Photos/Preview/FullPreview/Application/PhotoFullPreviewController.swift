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
}

protocol PhotoFullPreviewController: ErrorController {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func getPreview() -> PhotoFullPreview?
    func load()
    func clear()
}

enum PhotoFullPreviewError: Error {
    case noPreviewAvailable
}

// Will return full thumbnail for photo or full asset video url.
final class LocalPhotoFullPreviewController: PhotoFullPreviewController {
    private let id: PhotoId
    private let detailController: PhotoPreviewDetailController
    private let fullThumbnailController: ThumbnailController
    private let smallThumbnailController: ThumbnailController
    private let contentController: FileContentController
    private let publisher = ObservableObjectPublisher()
    private var fullPreview: PhotoFullPreview?
    private var cancellables = Set<AnyCancellable>()
    private var errorSubject = PassthroughSubject<Error, Never>()

    var updatePublisher: AnyPublisher<Void, Never> {
        publisher.eraseToAnyPublisher()
    }

    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    init(id: PhotoId, detailController: PhotoPreviewDetailController, fullThumbnailController: ThumbnailController, smallThumbnailController: ThumbnailController, contentController: FileContentController) {
        self.id = id
        self.detailController = detailController
        self.fullThumbnailController = fullThumbnailController
        self.smallThumbnailController = smallThumbnailController
        self.contentController = contentController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        fullThumbnailController.bootstrap()
        smallThumbnailController.bootstrap()
        
        let detailPublisher = detailController.photo.setFailureType(to: Error.self)
        Publishers.CombineLatest(detailPublisher, contentController.url)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.fallBackToThumbnails()
                }
            }, receiveValue: { [weak self] info, url in
                self?.handle(info: info, url: url)
            })
            .store(in: &cancellables)
    }

    private func subscribeToThumbnails() {
        Publishers.Merge(smallThumbnailController.updatePublisher, fullThumbnailController.updatePublisher)
            .sink { [weak self] in
                self?.handleThumbnailUpdate()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(smallThumbnailController.isFailed, fullThumbnailController.isFailed)
            .map { $0.0 && $0.1 }
            .filter { $0 }
            .sink { [weak self] _ in
                self?.errorSubject.send(PhotoFullPreviewError.noPreviewAvailable)
            }
            .store(in: &cancellables)
    }

    private func fallBackToThumbnails() {
        subscribeToThumbnails()
        fullThumbnailController.load()
        smallThumbnailController.load()
        handleThumbnailUpdate()
    }

    private func handle(info: PhotoInfo, url: URL) {
        switch info.type {
        case .photo:
            update(with: .image(url))
        case .video:
            update(with: .video(url))
        }
    }

    private func handleThumbnailUpdate() {
        switch fullPreview {
        case .none, .thumbnail:
            if let data = fullThumbnailController.getImage() ?? smallThumbnailController.getImage() {
                update(with: .thumbnail(data))
            }
        case .video, .image:
            break
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
        contentController.clear()
    }
}
