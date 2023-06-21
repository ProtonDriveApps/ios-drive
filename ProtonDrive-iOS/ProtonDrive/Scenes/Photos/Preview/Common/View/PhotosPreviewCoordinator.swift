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

import UIKit

final class PhotosPreviewCoordinator: PhotosPreviewListCoordinator, PhotosPreviewDetailFactory, PhotoPreviewDetailCoordinator {
    let container: PhotosPreviewContainer
    weak var rootViewController: UIViewController?

    init(container: PhotosPreviewContainer) {
        self.container = container
    }

    // MARK: - PhotosPreviewListCoordinator

    func close() {
        rootViewController?.dismiss(animated: true)
    }

    // MARK: - PhotosPreviewDetailFactory

    func makeViewController(with id: PhotoId) -> UIViewController {
        container.makeDetailViewController(with: id)
    }

    // MARK: - PhotoPreviewDetailCoordinator

    func openShare(with preview: PhotoFullPreview) {
        guard let rootViewController = rootViewController else {
            return
        }

        let item = getItem(from: preview)
        let viewController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        viewController.popoverPresentationController?.sourceView = rootViewController.view
        rootViewController.present(viewController, animated: true, completion: nil)
    }

    private func getItem(from preview: PhotoFullPreview) -> Any {
        switch preview {
        case .photo(let data):
            return data
        case .video(let url):
            return url
        }
    }
}
