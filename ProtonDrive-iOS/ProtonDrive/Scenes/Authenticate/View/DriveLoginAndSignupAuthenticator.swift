//
//  DriveLoginAndSignupAuthenticator.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 26.01.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

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
        OnboardingFlowTestsManager.skipOnboardingInTestsIfNeeded()
        removeLogoutFlagIfNeeded()
        if ProcessInfo.processInfo.environment["ExtAccountNotSupportedStub"] != nil {
            LoginExternalAccountNotSupportedSetup.start()
        }
        #endif
        
        authenticator.presentFlowFromWelcomeScreen(over: parent, welcomeScreen: .drive(.init(body: body)), customization: .empty) { result in
            switch result {
            case .dismissed:
                fatalError()
            case .loginStateChanged(.dataIsAvailable(.userData(let data))):
                userDataBlock(data)
            case .signupStateChanged(.dataIsAvailable(.userData(let data))):
                userDataBlock(data)
            case .loginStateChanged(.loginFinished):
                onCompletion()
            case .signupStateChanged(.signupFinished):
                onCompletion()
            default:
                break
            }
        }
    }
}

#if DEBUG
extension DriveLoginAndSignupAuthenticator {
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
