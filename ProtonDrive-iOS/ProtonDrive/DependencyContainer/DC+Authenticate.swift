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
import ProtonCoreChallenge
import ProtonCoreLoginUI
import ProtonCoreServices
import ProtonCoreEnvironment
import PDLocalization

extension DriveDependencyContainer {
    func makeAuthenticateViewController() -> AuthenticateViewController {
        let viewModel = makeAuthenticatorViewModel()
        let authenticator = makeAuthenticator()
        return AuthenticateViewController(viewModel: viewModel, authenticator: authenticator)
    }

    private func makeAuthenticatorViewModel() -> AuthenticateViewModel {
        AuthenticateViewModel(sessionStore: sessionVault,
                              sessionCommunicator: sessionCommunicator,
                              coordinator: AuthenticateCoordinator())
    }

    private func makeAuthenticator() -> DriveLoginAndSignupAuthenticator {
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
                summaryScreenVariant: .screenVariant(.drive(SummaryStartButtonText(Localization.sign_up_succeed_text)))
            )
        )
        #else
        let signUpAvailability = LoginFeatureAvailability<SignupParameters>.notAvailable
        #endif
        
        let authenticator = LoginAndSignup(appName: "ProtonDrive",
                              clientApp: .drive,
                              apiService: networkService,
                              minimumAccountType: .external,
                              isCloseButtonAvailable: false,
                              paymentsAvailability: paymentsAvailability,
                              signupAvailability: signUpAvailability)
        return DriveLoginAndSignupAuthenticator(authenticator: authenticator)
    }
}
