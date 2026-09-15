// Copyright (c) 2026 Proton AG
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
import PDLocalization

@MainActor
protocol FileExportCoordinatorProtocol: AnyObject {
    func showProgress(onCancel: @escaping () -> Void)
    func hideProgress(completion: @escaping () async -> Void)
    func share(_ urls: [URL])
}

@MainActor
final class FileExportCoordinator: FileExportCoordinatorProtocol {
    private weak var rootViewController: UIViewController?
    private weak var progressAlert: UIAlertController?

    nonisolated init(rootViewController: UIViewController?) {
        self.rootViewController = rootViewController
    }

    func showProgress(onCancel: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "\(Localization.general_downloading)...",
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Localization.general_cancel, style: .cancel, handler: { _ in onCancel() }))
        progressAlert = alert
        rootViewController?.present(alert, animated: false)
    }

    func hideProgress(completion: @escaping () async -> Void) {
        progressAlert?.dismiss(animated: true, completion: {
            Task { @MainActor in
                await completion()
            }
        })
    }

    func share(_ urls: [URL]) {
        guard let root = rootViewController, !urls.isEmpty else { return }
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        controller.excludedActivityTypes = [.assignToContact, .copyToPasteboard, .markupAsPDF, .print]
        controller.popoverPresentationController?.sourceView = root.view
        root.present(controller, animated: true, completion: nil)
    }
}
