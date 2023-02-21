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

public final class AuthenticateViewController: UIViewController {
    public var viewModel: AuthenticateViewModel!
    public var authenticator: LoginAndSignup!

    public var onAuthenticated: (() -> Void)?

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundNorm

        authenticator.authenticate(
            over: self,
            body: viewModel.welcomeBody,
            onCompletion: { [weak self] in self?.didAuthenticate($0) }
        )
    }

    private func didAuthenticate(_ userData: UserData) {
        viewModel.didAuthenticate(userData)
        onAuthenticated?()
    }
}

private extension LoginAndSignup {
    func authenticate(
        over parent: UIViewController,
        body: String,
        onCompletion: @escaping (UserData) -> Void
    ) {
        #if DEBUG
        OnboardingFlowTestsManager.skipOnboardingInTestsIfNeeded()
        removeLogoutFlagIfNeeded()
        if ProcessInfo.processInfo.environment["ExtAccountNotSupportedStub"] != nil {
            LoginExternalAccountNotSupportedSetup.start()
        }
        #endif

        presentFlowFromWelcomeScreen(over: parent, welcomeScreen: .drive(.init(body: body))) { result in
            switch result {
            case .dismissed:
                fatalError()

            case .loggedIn(let data):
                switch data {
                case .credential:
                    break
                case .userData(let userData):
                    onCompletion(userData)
                }

            case .signedUp(let data):
                switch data {
                case .credential:
                    break
                case .userData(let userData):
                    onCompletion(userData)
                }
            }
        }
    }
}

#if DEBUG
extension LoginAndSignup {
    private var testArgument: String { "--uitests" }
    private var clearArgument: String { "--clear_all_preference" }

    func removeLogoutFlagIfNeeded() {
        let arguments = CommandLine.arguments
        guard arguments.contains(testArgument),
              arguments.contains(clearArgument) else { return }

        CommandLine.arguments = arguments
            .filter { $0 != clearArgument }
    }
}
#endif
