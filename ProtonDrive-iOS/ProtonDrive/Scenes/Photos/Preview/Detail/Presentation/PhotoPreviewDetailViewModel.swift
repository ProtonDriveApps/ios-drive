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

protocol PhotoPreviewDetailViewModelProtocol: ObservableObject {
    var loading: String? { get }
    var thumbnail: Data? { get }
    var fullPreview: PhotoFullPreview? { get }
    func viewDidLoad()
    func toggleMode()
    func setActive()
    func share()
}

final class PhotoPreviewDetailViewModel: PhotoPreviewDetailViewModelProtocol {
    private let thumbnailController: ThumbnailController
    private let modeController: PhotosPreviewModeController
    private let previewController: PhotosPreviewController
    private let detailController: PhotoPreviewDetailController
    private let fullPreviewController: PhotoFullPreviewController
    private let id: PhotoId
    private var cancellables = Set<AnyCancellable>()

    @Published var loading: String?
    @Published var thumbnail: Data?
    @Published var fullPreview: PhotoFullPreview?

    init(thumbnailController: ThumbnailController, modeController: PhotosPreviewModeController, previewController: PhotosPreviewController, detailController: PhotoPreviewDetailController, fullPreviewController: PhotoFullPreviewController, id: PhotoId) {
        self.thumbnailController = thumbnailController
        self.modeController = modeController
        self.previewController = previewController
        self.detailController = detailController
        self.fullPreviewController = fullPreviewController
        self.id = id
        subscribeToUpdates()
        updateLoading()
    }

    func viewDidLoad() {
        if let image = thumbnailController.getImage() {
            thumbnail = image
        } else {
            thumbnailController.load()
        }
    }

    func toggleMode() {
        modeController.toggle()
    }

    func setActive() {
        previewController.setCurrent(id)
        detailController.execute(with: id)
    }

    func share() {
        // TODO: next MR
    }

    private func subscribeToUpdates() {
        thumbnailController.updatePublisher
            .sink { [weak self] _ in
                self?.reloadThumbnail()
            }
            .store(in: &cancellables)
    }

    private func reloadThumbnail() {
        guard let image = thumbnailController.getImage() else { return }
        if thumbnail != image {
            thumbnail = image
        }
    }

    private func updateLoading() {
        let isLoading = fullPreview == nil
        loading = isLoading ? "Loading..." : nil
    }
}
