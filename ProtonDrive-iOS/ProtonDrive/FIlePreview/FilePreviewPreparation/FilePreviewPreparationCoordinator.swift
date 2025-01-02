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

protocol FilePreviewPreparationCoordinatorProtocol {
    func onFileDecrypted() async
}

final class FilePreviewPreparationCoordinator: FilePreviewPreparationCoordinatorProtocol {
    weak var presentingController: UIAlertController?

    private weak var root: UIViewController?
    private let repository: FilePreviewRepository
    private let share: Bool

    init(repository: FilePreviewRepository, root: UIViewController!, share: Bool) {
        self.repository = repository
        self.share = share
        self.root = root
    }

    @MainActor
    func onFileDecrypted() async {
        presentingController?.dismiss(animated: true) { [repository, weak self] in
            guard let self else { return }
            self.openPreview(repository: repository)
        }
    }

    private func openPreview(repository: FilePreviewRepository) {
        let model = FileModel(repository: repository)
        let vc = PMPreviewController()
        vc.model = model
        vc.delegate = model
        vc.dataSource = model
        vc.share = share
        vc.modalPresentationStyle = .fullScreen
        vc.isModalInPresentation = false
        root?.present(vc, animated: true)
    }
}
