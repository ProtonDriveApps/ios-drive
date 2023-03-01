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

import PDCore
import ProtonCore_Login
import ProtonCore_LoginUI
import ProtonCore_UIFoundations

final class AuthenticateViewController: UIViewController {
    private let viewModel: AuthenticateViewModel
    private let authenticator: DriveLoginAndSignupAuthenticator
    
    init(viewModel: AuthenticateViewModel, authenticator: DriveLoginAndSignupAuthenticator) {
        self.viewModel = viewModel
        self.authenticator = authenticator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundNorm

        authenticator.authenticate(
            over: self,
            body: viewModel.welcomeBody,
            userDataBlock: { [weak self] data in
                self?.viewModel.save(data)
            },
            onCompletion: { [weak self] in
                self?.viewModel.completeAuthentication()
            }
        )
    }
}
