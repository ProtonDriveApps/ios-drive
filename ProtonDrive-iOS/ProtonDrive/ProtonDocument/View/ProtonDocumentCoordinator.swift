// Copyright (c) 2024 Proton AG
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

import PDCore
import PDClient
import SafariServices
import UIKit

protocol ProtonDocumentCoordinatorProtocol: URLCoordinatorProtocol {
    func openPreview(identifier: ProtonDocumentIdentifier)
    func openShare(url: URL, completion: @escaping () -> Void)
    func openRename(identifier: ProtonDocumentIdentifier)
}

final class ProtonDocumentCoordinator: ProtonDocumentCoordinatorProtocol {
    private let container: ProtonDocumentPreviewContainer
    weak var rootViewController: UIViewController?
    private weak var previewViewController: UIViewController?

    init(container: ProtonDocumentPreviewContainer) {
        self.container = container
    }

    func openExternal(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    func openPreview(identifier: ProtonDocumentIdentifier) {
        guard let rootViewController else {
            return
        }

        let openingController = container.makeController(rootViewController: rootViewController)
        let previewViewController = container.makePreviewViewController(identifier: identifier, coordinator: self, openingController: openingController)
        let navigationViewController = ModalNavigationViewController(rootViewController: previewViewController)
        navigationViewController.modalPresentationStyle = .overFullScreen
        rootViewController.present(navigationViewController, animated: true)
        self.previewViewController = previewViewController
    }

    func openShare(url: URL, completion: @escaping () -> Void) {
        guard let previewViewController else {
            return
        }
        guard let navigationBar = previewViewController.navigationController?.navigationBar else {
            return
        }

        let viewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        viewController.modalPresentationStyle = .formSheet
        viewController.completionWithItemsHandler = { _, _, _, _ in
            completion()
        }
        // Since the activity is opened from webview, we don't know the exact view -> using navigation bar instead
        viewController.popoverPresentationController?.sourceView = navigationBar
        viewController.popoverPresentationController?.sourceRect = navigationBar.bounds
        previewViewController.present(viewController, animated: true, completion: nil)
    }

    func openRename(identifier: ProtonDocumentIdentifier) {
        guard let previewViewController else {
            return
        }

        guard let viewController = container.makeRenameViewController(identifier: identifier) else {
            return
        }

        let navigationViewController = UINavigationController(rootViewController: viewController)
        navigationViewController.isModalInPresentation = true
        previewViewController.present(navigationViewController, animated: true)
    }
}
