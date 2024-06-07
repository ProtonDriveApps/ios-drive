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

protocol PhotoPreviewDetailShareController {
    func openShare()
}

final class CachingPhotoPreviewDetailShareController: PhotoPreviewDetailShareController {
    private let id: PhotoId
    private let fileContentController: FileContentController
    private let coordinator: PhotoPreviewDetailCoordinator
    private var url: URL?
    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()

    init(fileContentController: FileContentController, coordinator: PhotoPreviewDetailCoordinator, id: PhotoId) {
        self.fileContentController = fileContentController
        self.coordinator = coordinator
        self.id = id
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        fileContentController.url
            .sink { [weak self] _ in
                self?.isLoading = false
            } receiveValue: { [weak self] url in
                self?.handleUpdate(url)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ url: URL) {
        self.url = url
        if isLoading {
            coordinator.openShare(url: url)
        }
        isLoading = false
    }

    func openShare() {
        if let url = url {
            coordinator.openShare(url: url)
        } else {
            isLoading = true
            fileContentController.execute(with: id)
        }
    }
}
