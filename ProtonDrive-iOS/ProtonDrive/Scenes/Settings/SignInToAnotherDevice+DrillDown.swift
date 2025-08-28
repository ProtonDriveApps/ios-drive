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
import PMSettings
import ProtonCoreServices
import ProtonCoreLoginUI
import PDLocalization
import SwiftUI

class SignInToAnotherDeviceItem: PMDrillDownCellViewModel {
    var accessibilityIdentifier: String { "Sign_In_To_Another_Device" }

    var preview: String? { nil }
    var title: String { Localization.sign_in_to_another_device }
    let apiService: APIService
    let passphrase: String
    let email: String

    init(apiService: APIService, passphrase: String, email: String) {
        self.apiService = apiService
        self.passphrase = passphrase
        self.email = email
    }

    @MainActor
    var controller: ShowingNavigationBarUIHostingController {
        let qrCodeInstructionsView = ScanQRCodeInstructionsView(
            viewModel: .init(dependencies: .init(passphrase: passphrase,
                                                 userEmail: email,
                                                 apiService: apiService)))

        let hostingController = ShowingNavigationBarUIHostingController(
            rootView: AnyView(qrCodeInstructionsView)
        )

        return hostingController
    }
}

class ShowingNavigationBarUIHostingController: UIHostingController<AnyView> {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = false
    }
}
