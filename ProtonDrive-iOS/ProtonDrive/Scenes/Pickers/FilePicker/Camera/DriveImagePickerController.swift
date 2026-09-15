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

import AVFoundation
import Foundation
import PDLocalization
import UIKit

final class DriveImagePickerController: UIImagePickerController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let cameraMediaType = AVMediaType.video
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: cameraMediaType)

        switch cameraAuthorizationStatus {
        case .authorized:
            break
        case .denied:
            presentAlert()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: cameraMediaType) { _ in }
        default:
            break
        }
    }

    func presentAlert() {
        let alert = UIAlertController(
            title: Localization.camera_permission_alert_title,
            message: Localization.camera_permission_alert_message,
            preferredStyle: UIAlertController.Style.alert
        )

        alert.addAction(
            UIAlertAction(title: Localization.general_cancel, style: UIAlertAction.Style.cancel)
        )

        alert.addAction(
            UIAlertAction(
                title: Localization.general_settings,
                style: UIAlertAction.Style.default,
                handler: { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            )
        )

        self.present(alert, animated: true, completion: nil)
    }
}
