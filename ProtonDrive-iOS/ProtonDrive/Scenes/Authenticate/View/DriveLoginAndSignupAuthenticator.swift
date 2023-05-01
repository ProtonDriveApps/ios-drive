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

import ProtonCore_Login
import ProtonCore_LoginUI

final class DriveLoginAndSignupAuthenticator {
    private let authenticator: LoginAndSignupInterface
    private var userData: UserData?
    
    init(authenticator: LoginAndSignupInterface) {
        self.authenticator = authenticator
    }
    
    func authenticate(
        over parent: UIViewController,
        body: String,
        userDataBlock: @escaping (UserData) -> Void,
        onCompletion: @escaping () -> Void
    ) {
        #if DEBUG
        removeLogoutFlagIfNeeded()
        if ProcessInfo.processInfo.environment["ExtAccountNotSupportedStub"] != nil {
            LoginExternalAccountNotSupportedSetup.start()
        }
        #endif
        
        authenticator.presentFlowFromWelcomeScreen(over: parent, welcomeScreen: .drive(.init(body: body)), customization: .empty) { (result: LoginAndSignupResult) in
            switch result {
            case .dismissed:
                fatalError()
            case .loginStateChanged(.dataIsAvailable(let data)), .signupStateChanged(.dataIsAvailable(let data)):
                userDataBlock(data)
            case .loginStateChanged(.loginFinished), .signupStateChanged(.signupFinished):
                onCompletion()
            }
        }
    }
}

#if DEBUG
extension DriveLoginAndSignupAuthenticator {
    private var clearArgument: String { "--clear_all_preference" }

    func removeLogoutFlagIfNeeded() {
        let arguments = CommandLine.arguments
        guard arguments.contains(UITestsFlag.uiTests.content),
              arguments.contains(clearArgument) else { return }

        CommandLine.arguments = arguments
            .filter { $0 != clearArgument }
    }
}
#endif
