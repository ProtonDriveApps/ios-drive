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
import PDCoreIOS

protocol NativeSharePhotoControllerProtocol {
    var coordinator: NativeSharePhotoCoordinatorProtocol { get }

    func share(id: PhotoId)
}

final class NativeSharePhotoController: NativeSharePhotoControllerProtocol {
    let coordinator: NativeSharePhotoCoordinatorProtocol
    private let fileContentController: FileContentController
    private var cancellables: Set<AnyCancellable> = []

    init(
        coordinator: NativeSharePhotoCoordinatorProtocol,
        fileContentController: FileContentController
    ) {
        self.coordinator = coordinator
        self.fileContentController = fileContentController
        subscribeToUpdates()
    }

    func share(id: PhotoId) {
        fileContentController.execute(with: id)
    }

    private func subscribeToUpdates() {
        fileContentController.content
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] content in
                self?.handleFileUpdate(content)
            })
            .store(in: &cancellables)
    }

    private func handleFileUpdate(_ content: FileContent?) {
        guard let content, !content.isLoading else {
            UserMessageHandler().handleWarning(Localization.general_loading)
            return
        }

        if content.couldBeLivePhoto, let videoURL = content.childrenURLs.first {
            coordinator.openNativeShareForLivePhoto(imageURL: content.url, videoURL: videoURL) { [weak self] in
                self?.fileContentController.clear()
            }
        } else if content.couldBeBurst {
            coordinator.openNativeShareForBurstPhoto(urls: [content.url] + content.childrenURLs) { [weak self] in
                self?.fileContentController.clear()
            }
        } else {
            share(url: content.url)
        }
    }

    private func share(url: URL) {
        coordinator.openNativeShare(url: url) { [weak self] in
            self?.fileContentController.clear()
        }
    }
}
