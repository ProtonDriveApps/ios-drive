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

import UIKit
import SwiftUI
import PDCore
import PDCoreIOS
import PDLocalization

final class FilePreviewPreparationCoordinator {
    private let messageHandler: UserMessageHandlerProtocol
    private let repository: FilePreviewRepository
    private var performanceMetricsController: PerformanceMetricsControllerProtocol?
    private weak var presentingController: UIAlertController?
    private weak var root: UIViewController?

    init(
        messageHandler: UserMessageHandlerProtocol,
        repository: FilePreviewRepository,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        root: UIViewController
    ) {
        self.messageHandler = messageHandler
        self.repository = repository
        self.performanceMetricsController = performanceMetricsController
        self.root = root
    }
    
    func preview() async {
        do {
            if try await repository.requiresDecryption() {
                await presentAlert()
                try await repository.loadFile()
                await presentingController?.dismiss(animated: false)
            }
            await openPreview(repository: repository)
        } catch {
            if error is CancellationError { return }
            Log.error("Preview file failed", error: error, domain: .scenes)
            messageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
    }
    
    @MainActor
    private func presentAlert() {
        let alert = UIAlertController(title: Localization.general_decrypting, message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: Localization.general_cancel, style: .cancel) { [weak repository] _ in
            repository?.cancel()
        }
        alert.addAction(cancelAction)
        presentingController = alert
        root?.present(alert, animated: false)
    }

    @MainActor
    private func openPreview(repository: FilePreviewRepository) {
        let model = FileModel(
            repository: repository,
            performanceMetricsController: performanceMetricsController,
            messageHandler: messageHandler
        )
        let vc = PMPreviewController()
        vc.model = model
        vc.delegate = model
        vc.dataSource = model
        vc.modalPresentationStyle = .fullScreen
        vc.isModalInPresentation = false
        root?.present(vc, animated: true)
    }
}
