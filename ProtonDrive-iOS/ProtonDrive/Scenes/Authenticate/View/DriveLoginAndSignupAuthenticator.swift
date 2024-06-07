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
import ProtonCoreLogin
import ProtonCoreLoginUI

final class DriveLoginAndSignupAuthenticator {
    private let authenticator: LoginAndSignupInterface
    private var userData: UserData?
    
    init(authenticator: LoginAndSignupInterface) {
        self.authenticator = authenticator
    }
    
    func authenticate(
        over parent: UIViewController,
        body: String,
        customization: LoginCustomizationOptions = .empty,
        userDataBlock: @escaping (UserData, @escaping (Error) -> Void) -> Void,
        onCompletion: @escaping () -> Void
    ) {
        #if DEBUG
        removeLogoutFlagIfNeeded()
        if ProcessInfo.processInfo.environment["ExtAccountNotSupportedStub"] != nil {
            LoginExternalAccountNotSupportedSetup.start()
        }
        #endif
        
        authenticator.presentFlowFromWelcomeScreen(
            over: parent,
            welcomeScreen: .drive(.init(body: body)),
            customization: customization
        ) { [weak self] result in
            self?.handleLoginResult(parent, result, userDataBlock, onCompletion)
        }
    }
    
    private func handleLoginResult(
        _ parent: UIViewController,
        _ result: LoginAndSignupResult,
        _ userDataBlock: @escaping (UserData, @escaping (Error) -> Void) -> Void,
        _ onCompletion: @escaping () -> Void
    ) {
        switch result {
        case .dismissed:
            fatalError()
        case .loginStateChanged(.dataIsAvailable(let data)), .signupStateChanged(.dataIsAvailable(let data)):
            userDataBlock(data) { [weak self] error in
                guard let self else { return }
                // in case of error, the file provider won't work at all
                // therefore we retry the login
                self.authenticator.presentLoginFlow(
                    over: parent,
                    customization: .init(initialError: error.localizedDescription)
                ) { [weak self] (result: LoginAndSignupResult) in
                    self?.handleLoginResult(parent, result, userDataBlock, onCompletion)
                }
            }
        case .loginStateChanged(.loginFinished), .signupStateChanged(.signupFinished):
            onCompletion()
        }
    }
}

#if DEBUG
extension DriveLoginAndSignupAuthenticator {
    func removeLogoutFlagIfNeeded() {
        guard DebugConstants.commandLineContains(flags: [.uiTests, .clearAllPreference]) else {
            return
        }

        DebugConstants.removeCommandLine(flags: [.clearAllPreference])
    }
}
#endif
