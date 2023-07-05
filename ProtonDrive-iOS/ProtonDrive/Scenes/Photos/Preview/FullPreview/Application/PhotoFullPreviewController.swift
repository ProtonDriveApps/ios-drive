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

enum PhotoFullPreview: Equatable {
    case photo(Data)
    case video(URL)
}

protocol PhotoFullPreviewController {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func getPreview() -> PhotoFullPreview?
    func clear()
}

// Will return full thumbnail for photo or full asset video url.
final class LocalPhotoFullPreviewController: PhotoFullPreviewController {
    private let detailController: PhotoPreviewDetailController
    private let thumbnailController: ThumbnailController
    private let contentController: FileContentController
    private let storageResource: LocalStorageResource
    private let publisher = ObservableObjectPublisher()
    private var fullPreview: PhotoFullPreview?
    private var cancellables = Set<AnyCancellable>()

    var updatePublisher: AnyPublisher<Void, Never> {
        publisher.eraseToAnyPublisher()
    }

    init(detailController: PhotoPreviewDetailController, thumbnailController: ThumbnailController, contentController: FileContentController, storageResource: LocalStorageResource) {
        self.detailController = detailController
        self.thumbnailController = thumbnailController
        self.contentController = contentController
        self.storageResource = storageResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        detailController.photo
            .removeDuplicates()
            .sink { [weak self] info in
                self?.handleInfo(info)
            }
            .store(in: &cancellables)

        thumbnailController.updatePublisher
            .compactMap { [weak self] in
                self?.thumbnailController.getImage()
            }
            .sink { [weak self] data in
                self?.fullPreview = .photo(data)
                self?.publisher.send()
            }
            .store(in: &cancellables)

        contentController.url
            .sink { [weak self] url in
                self?.update(with: .video(url))
            }
            .store(in: &cancellables)
    }

    private func handleInfo(_ info: PhotoInfo) {
        switch info.type {
        case .photo:
            handlePhotoUpdate()
        case .video:
            contentController.execute(with: info.id)
        }
    }

    private func handlePhotoUpdate() {
        if let image = thumbnailController.getImage() {
            update(with: .photo(image))
        } else {
            thumbnailController.load()
        }
    }

    private func update(with fullPreview: PhotoFullPreview) {
        if self.fullPreview != fullPreview {
            self.fullPreview = fullPreview
            publisher.send()
        }
    }

    func getPreview() -> PhotoFullPreview? {
        fullPreview
    }

    func clear() {
        if case let .video(url) = fullPreview {
            try? storageResource.delete(at: url)
        }
    }
}
