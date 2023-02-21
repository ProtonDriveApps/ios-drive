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
import ProtonCore_LoginUI
import ProtonCore_Services
import ProtonCore_Environment

extension DriveDependencyContainer {
    func makeAuthenticateViewController() -> AuthenticateViewController {
        let viewController = AuthenticateViewController()
        let viewModel = makeAuthenticatorViewModel()
        let authenticator = makeAuthenticator()
        let coordinator = makeAuthenticateCoordinator(viewController)

        viewController.viewModel = viewModel
        viewController.authenticator = authenticator
        viewController.onAuthenticated = coordinator.onAuthenticated

        return viewController
    }

    private func makeAuthenticatorViewModel() -> AuthenticateViewModel {
        AuthenticateViewModel(sessionStore: sessionVault)
    }

    private func makeAuthenticator() -> LoginAndSignup {
        #if HAS_PAYMENTS
        let paymentsAvailability = PaymentsAvailability.available(
            parameters: PaymentsParameters(
                listOfIAPIdentifiers: Constants.drivePlanIDs,
                listOfShownPlanNames: Constants.shownPlanNames,
                reportBugAlertHandler: nil
            )
        )
        #else
        let paymentsAvailability = PaymentsAvailability.notAvailable
        #endif
        
        #if HAS_SIGNUP
        let signUpAvailability = LoginFeatureAvailability.available(
            parameters: SignupParameters(
                separateDomainsButton: true,
                passwordRestrictions: .default,
                summaryScreenVariant: .screenVariant(.drive(SummaryStartButtonText("Start using Proton Drive")))
            )
        )
        #else
        let signUpAvailability = LoginFeatureAvailability<SignupParameters>.notAvailable
        #endif
        
        return LoginAndSignup(appName: "ProtonDrive",
                              clientApp: .drive,
                              environment: Constants.clientApiConfig.environment,
                              trustKit: PMAPIService.trustKit,
                              apiServiceDelegate: networkClient,
                              forceUpgradeDelegate: networkClient,
                              minimumAccountType: .external,
                              isCloseButtonAvailable: false,
                              paymentsAvailability: paymentsAvailability,
                              signupAvailability: signUpAvailability)
    }

    private func makeAuthenticateCoordinator(_ viewController: AuthenticateViewController) -> AuthenticateCoordinator {
        AuthenticateCoordinator(viewController: viewController)
    }
}
