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

import Foundation
import SwiftUI
import PDCore
import UIKit

final class StorageDiagnosticsCoordinator {
    private weak var rootVC: UIViewController?

    func start(storageManager: StorageManager) -> UIViewController {
        let vm = StorageDiagnosticsViewModel(storageManager: storageManager, coordinator: self)
        let view = StorageDiagnosticsView(viewModel: vm)
        let vc = UIHostingController(rootView: view)
        rootVC = vc

        return vc
    }

    func presentClearTempFolderAlert(clearAction: @escaping () -> Void) {
        guard let rootVC else { return }
        let alertVC = UIAlertController(
            title: "Clear temporary folder",
            message: "Are you sure you want to clear temporary folder? This will NOT remove your offline available content.",
            preferredStyle: .alert
        )
        alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertVC.addAction(
            UIAlertAction(title: "Clear temporary folder", style: .destructive) { _ in
                clearAction()
            }
        )
        rootVC.present(alertVC, animated: true)
    }
}
