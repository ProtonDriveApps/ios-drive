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
    func onAppear()
    func onDisappear()
    func openPreview()
}

struct PhotoItemViewModelData {
    let image: Data?
    let duration: String?
}

final class PhotoItemViewModel: PhotoItemViewModelProtocol {
    private let item: PhotoGridViewItem
    private let thumbnailController: ThumbnailController
    private let coordinator: PhotoItemCoordinator
    private var cancellables = Set<AnyCancellable>()

    let duration: String?
    @Published var image: Data?

    init(item: PhotoGridViewItem, thumbnailController: ThumbnailController, coordinator: PhotoItemCoordinator) {
        self.item = item
        self.thumbnailController = thumbnailController
        self.coordinator = coordinator
        duration = item.duration
        subscribeToUpdates()
        reloadImage()
    }

    private func subscribeToUpdates() {
        thumbnailController.updatePublisher
            .sink { [weak self] _ in
                self?.reloadImage()
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        if let image = thumbnailController.getImage() {
            self.image = image
        } else {
            thumbnailController.load()
        }
    }

    func onDisappear() {
        thumbnailController.cancel()
    }

    private func makeThumbnailIdentifier() -> NodeIdentifier {
        NodeIdentifier(item.photoId, item.shareId)
    }

    private func reloadImage() {
        let image = thumbnailController.getImage()
        if self.image != image {
            self.image = image
        }
    }

    func openPreview() {
        let identifier = makeThumbnailIdentifier()
        coordinator.openPreview(with: identifier)
    }
}
