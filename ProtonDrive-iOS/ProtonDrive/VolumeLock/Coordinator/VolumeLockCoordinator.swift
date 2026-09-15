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

import PDCore
import PDLocalization
import UIKit
import SafariServices

@MainActor
final class VolumeLockCoordinator: NSObject {
    private weak var controller: VolumeLockController?
    private let recoveryInteractor: VolumeLockRecoveryInteractorProtocol

    init(controller: VolumeLockController, recoveryInteractor: VolumeLockRecoveryInteractorProtocol) {
        self.controller = controller
        self.recoveryInteractor = recoveryInteractor
        super.init()
    }

    func presentRecoveryDetails(from viewController: UIViewController?) {
        Task {
            do {
                let url = try await recoveryInteractor.execute()
                guard
                    let presenter = viewController ?? UIApplication.shared.topMostViewControllerFromAppWindow()
                else {
                    Log.warning("Can't find most top view controller", domain: .application)
                    return
                }
                present(url: url, from: presenter)
            } catch {
                Log.error("Generate volume lock recovery url failed", error: error, domain: .application)
            }
        }
    }

    func presentSkipConfirmation(from viewController: UIViewController?, onConfirm: @escaping () -> Void) {
        guard let presenter = viewController ?? UIApplication.shared.topMostViewControllerFromAppWindow() else {
            Log.warning("Can't find most top view controller", domain: .application)
            return
        }

        let alert = UIAlertController(
            title: Localization.volume_lock_skip_alert_title,
            message: Localization.volume_lock_skip_alert_message,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: Localization.general_skip, style: .default) { _ in
                onConfirm()
            }
        )
        alert.addAction(UIAlertAction(title: Localization.general_cancel, style: .cancel))
        presenter.present(alert, animated: true)
    }

    private func present(url: URL, from presenter: UIViewController) {
        let safari = SFSafariViewController(url: url)
        safari.delegate = self
        presenter.present(safari, animated: true)
    }
}

extension VolumeLockCoordinator: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        let lockController = self.controller
        Task { @MainActor [weak lockController] in
            await lockController?.checkSilently()
        }
    }
}
