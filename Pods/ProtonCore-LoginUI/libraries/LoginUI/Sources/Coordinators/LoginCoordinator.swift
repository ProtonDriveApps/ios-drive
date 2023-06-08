//
//  LoginCoordinator.swift
//  ProtonCore-Login - Created on 03/11/2020.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import UIKit
import ProtonCore_UIFoundations
import ProtonCore_Login
import ProtonCore_Authentication
import ProtonCore_Networking
import ProtonCore_CoreTranslation
import ProtonCore_TroubleShooting
import ProtonCore_FeatureSwitch
import ProtonCore_Services
import ProtonCore_Utilities

protocol LoginCoordinatorDelegate: AnyObject {
    func userDidDismissLoginCoordinator(loginCoordinator: LoginCoordinator)
    func loginCoordinatorDidFinish(loginCoordinator: LoginCoordinator, data: LoginData)
    func userSelectedSignup(navigationController: LoginNavigationViewController)
}

final class LoginCoordinator {
    enum ChildCoordinators {
        case createAddress
    }

    weak var delegate: LoginCoordinatorDelegate?
    var initialError: LoginError?

    private let container: Container
    private let isCloseButtonAvailable: Bool
    private let isSignupAvailable: Bool
    private var navigationController: LoginNavigationViewController?
    private var childCoordinators: [ChildCoordinators: Any] = [:]
    private let externalLinks: ExternalLinks
    private var customization: LoginCustomizationOptions

    private var sessionInvalidatedDueToUserGoingBackToRootController = false

    init(container: Container,
         isCloseButtonAvailable: Bool,
         isSignupAvailable: Bool,
         customization: LoginCustomizationOptions) {
        self.container = container
        self.isCloseButtonAvailable = isCloseButtonAvailable
        self.isSignupAvailable = isSignupAvailable
        self.customization = customization
        externalLinks = container.makeExternalLinks()
        if let initialErrorString = customization.initialError {
            self.initialError = LoginError.initialError(message: initialErrorString)
        }
        self.container.api.authDelegate?.authSessionInvalidatedDelegateForLoginAndSignup = self
    }

    @discardableResult
    func start(_ kind: FlowStartKind, username: String? = nil) -> UINavigationController {
        showInitialViewController(kind, initialViewController: loginViewController(username: username))
    }

    func startFromWelcomeScreen(
        viewController: UIViewController, variant: WelcomeScreenVariant, username: String? = nil
    ) -> UINavigationController {
        let welcome = WelcomeViewController(variant: variant, delegate: self, username: username, signupAvailable: isSignupAvailable)
        return showInitialViewController(.over(viewController, .crossDissolve), initialViewController: welcome, navigationBarHidden: true)
    }

    func startWithUnmanagedWelcomeScreen(variant: WelcomeScreenVariant, username: String? = nil) -> UINavigationController {
        let welcome = WelcomeViewController(variant: variant, delegate: self, username: username, signupAvailable: isSignupAvailable)
        return showInitialViewController(.unmanaged, initialViewController: welcome, navigationBarHidden: true)
    }

    private func loginViewController(username: String?) -> UIViewController {
        let loginViewController = UIStoryboard.instantiate(LoginViewController.self)
        loginViewController.viewModel = container.makeLoginViewModel()
        loginViewController.customErrorPresenter = customization.customErrorPresenter
        loginViewController.initialUsername = username
        loginViewController.delegate = self
        loginViewController.showCloseButton = isCloseButtonAvailable
        loginViewController.initialError = initialError
        loginViewController.isSignupAvailable = isSignupAvailable
        loginViewController.onDohTroubleshooting = { [weak self] in
            guard let self = self else { return }
            self.container.executeDohTroubleshootMethodFromApiDelegate()
            
            guard let nav = self.navigationController else { return }
            self.container.troubleShootingHelper.showTroubleShooting(over: nav)
        }
        return loginViewController
    }

    // MARK: - Actions
    private func showInitialViewController(
        _ kind: FlowStartKind,
        initialViewController: UIViewController,
        navigationBarHidden: Bool = false
    ) -> UINavigationController {
        switch kind {
        case .unmanaged:
            return embedInNavigationController(initialViewController: initialViewController,
                                               navigationBarHidden: navigationBarHidden)
        case let .over(viewController, modalTransitionStyle):
            let navigationController = embedInNavigationController(initialViewController: initialViewController,
                                                                   navigationBarHidden: navigationBarHidden)
            navigationController.modalTransitionStyle = modalTransitionStyle
            viewController.present(navigationController, animated: true, completion: nil)
            return navigationController
        case .inside(let navigationViewController):
            self.navigationController = navigationViewController
            navigationController?.setViewControllers([initialViewController], animated: true)
            return navigationViewController
        }
    }

    private func embedInNavigationController(initialViewController: UIViewController,
                                             navigationBarHidden: Bool) -> UINavigationController {
        let navigationController = LoginNavigationViewController(rootViewController: initialViewController,
                                                                 navigationBarHidden: navigationBarHidden)
        self.navigationController = navigationController
        return navigationController
    }

    private func showHelp() {
        let helpViewController = UIStoryboard.instantiate(HelpViewController.self)
        helpViewController.delegate = self
        helpViewController.viewModel = HelpViewModel(helpDecorator: customization.helpDecorator)
        navigationController?.present(helpViewController, animated: true, completion: nil)
    }

    private func showTwoFactorCode() {
        let twoFactorViewController = UIStoryboard.instantiate(TwoFactorViewController.self)
        twoFactorViewController.viewModel = container.makeTwoFactorViewModel()
        twoFactorViewController.customErrorPresenter = customization.customErrorPresenter
        twoFactorViewController.delegate = self
        twoFactorViewController.onDohTroubleshooting = { [weak self] in
            guard let self = self else { return }
            self.container.executeDohTroubleshootMethodFromApiDelegate()
            
            guard let nav = self.navigationController else { return }
            self.container.troubleShootingHelper.showTroubleShooting(over: nav)
        }
        navigationController?.pushViewController(twoFactorViewController, animated: true)
    }

    private func showMailboxPassword() {
        let mailboxPasswordViewController = UIStoryboard.instantiate(MailboxPasswordViewController.self)
        mailboxPasswordViewController.viewModel = container.makeMailboxPasswordViewModel()
        mailboxPasswordViewController.customErrorPresenter = customization.customErrorPresenter
        mailboxPasswordViewController.delegate = self
        mailboxPasswordViewController.onDohTroubleshooting = { [weak self] in
            guard let self = self else { return }
            self.container.executeDohTroubleshootMethodFromApiDelegate()
            
            guard let nav = self.navigationController else { return }
            self.container.troubleShootingHelper.showTroubleShooting(over: nav)
        }
        navigationController?.pushViewController(mailboxPasswordViewController, animated: true)
    }

    private func showCreateAddress(data: CreateAddressData, defaultUsername: String?) {
        guard let navigationController = navigationController else {
            fatalError("Invalid call")
        }

        let coordinator = CreateAddressCoordinator(
            container: container, navigationController: navigationController,
            data: data, customErrorPresenter: customization.customErrorPresenter,
            defaultUsername: defaultUsername
        )
        coordinator.delegate = self
        childCoordinators[.createAddress] = coordinator
        coordinator.start()
    }

    private func finish(endLoading: @escaping () -> Void, data: LoginData) {
        guard let performBeforeFlow = customization.performBeforeFlow else {
            completeLoginFlow(data: data)
            return
        }
        DispatchQueue.main.async { [weak self] in
            performBeforeFlow.completion(data) { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    endLoading()
                    switch result {
                    case .success:
                        self?.completeLoginFlow(data: data)
                    case .failure(let error):
                        self?.popAndShowError(error: .generic(message: error.messageForTheUser,
                                                              code: error.bestShotAtReasonableErrorCode,
                                                              originalError: error))
                    }
                }
            }
        }
    }

    private func completeLoginFlow(data: LoginData) {
        navigationController?.dismiss(animated: true, completion: nil)
        delegate?.loginCoordinatorDidFinish(loginCoordinator: self, data: data)
    }

    private func popAndShowError(error: LoginError) {
        clearSessionAndPopToRootViewController(animated: true) { navigationController in
            guard let viewController = navigationController.topViewController else { return }
            if self.customization.customErrorPresenter?.willPresentError(error: error, from: viewController) == true {
                return
            }
            
            guard let errorCapable = viewController as? LoginErrorCapable else { return }
            errorCapable.showError(error: error)
        }
    }
    
    private func popAndShowInfo(message: String) {
        clearSessionAndPopToRootViewController(animated: true) { navigationController in
            guard let viewController = navigationController.topViewController else { return }
            guard let errorCapable = viewController as? LoginErrorCapable else { return }
            errorCapable.showInfo(message: message)
        }
    }
}

// MARK: - Login steps delegate

extension LoginCoordinator: LoginStepsDelegate {
    func firstPasswordChangeNeeded() {
        UIApplication.openURLIfPossible(externalLinks.accountSetup)
    }

    func twoFactorCodeNeeded() {
        showTwoFactorCode()
    }

    func mailboxPasswordNeeded() {
        showMailboxPassword()
    }

    func createAddressNeeded(data: CreateAddressData, defaultUsername: String?) {
        if FeatureFactory.shared.isEnabled(.externalAccountConversion) {
            showCreateAddress(data: data, defaultUsername: defaultUsername)
        } else {
            // account conversion not supported by feature flag
            let externalAccountsNotSupportedError = LoginError.externalAccountsNotSupported(
                message: CoreString._ls_external_accounts_not_supported_popup_local_desc,
                title: CoreString._ls_external_accounts_address_required_popup_title,
                originalError: NSError()
            )
            popAndShowError(error: externalAccountsNotSupportedError)
        }
    }

    func userAccountSetupNeeded() {
        UIApplication.openURLIfPossible(externalLinks.accountSetup)
    }
    
    func learnMoreAboutExternalAccountsNotSupported() {
        UIApplication.openURLIfPossible(externalLinks.learnMoreAboutExternalAccountsNotSupported)
    }
}

// MARK: - Login VC delegate

extension LoginCoordinator: LoginViewControllerDelegate {
    func userDidDismissLoginViewController() {
        navigationController?.dismiss(animated: true, completion: nil)
        delegate?.userDidDismissLoginCoordinator(loginCoordinator: self)
    }

    func userDidRequestSignup() {
        guard let navigationController = navigationController else { return }
        delegate?.userSelectedSignup(navigationController: navigationController)
    }

    func userDidRequestHelp() {
        showHelp()
    }

    func loginViewControllerDidFinish(endLoading: @escaping () -> Void, data: LoginData) {
        finish(endLoading: endLoading, data: data)
    }
}

// MARK: - Help VC delegate

extension LoginCoordinator: HelpViewControllerDelegate {
    func userDidDismissHelpViewController() {
        navigationController?.presentedViewController?.dismiss(animated: true, completion: nil)
    }

    func userDidRequestHelp(item: HelpItem) {
        switch item {
        case .forgotUsername:
            UIApplication.openURLIfPossible(externalLinks.forgottenUsername)
        case .forgotPassword:
            UIApplication.openURLIfPossible(externalLinks.passwordReset)
        case .otherIssues:
            UIApplication.openURLIfPossible(externalLinks.commonLoginProblems)
        case .support:
            UIApplication.openURLIfPossible(externalLinks.support)
        case .staticText:
            break
        case .custom(_, _, let behaviour):
            guard let viewController = navigationController?.presentedViewController as? HelpViewController
            else { return }
            behaviour(viewController)
        }
    }
}

// MARK: - Create address delegate

extension LoginCoordinator: CreateAddressCoordinatorDelegate {
    func createAddressCoordinatorDidFinish(endLoading: @escaping () -> Void,
                                           createAddressCoordinator: CreateAddressCoordinator,
                                           data: LoginData) {
        childCoordinators[.createAddress] = nil
        finish(endLoading: endLoading, data: data)
    }
}

// MARK: - LoginCoordinator delegate

extension LoginCoordinator: NavigationDelegate {

    func userDidGoBack() {

        guard let navigationController = navigationController else { return }

        if
            // if there are 2 or less VCs on the navigation stack, popping one means just popping to the root
            navigationController.viewControllers.count <= 2 ||

            // Special case for situation in which we've already sent a valid 2FA code to server.
            // Once we do it, the user auth session on the backend is past the 2FA step and doesn't allow sending another 2FA code again.
            // The technical details are: the access token contains `twofactor` scope before `POST /auth/v4/2fa` and doesn't contain it after.
            // It makes navigating back to two factor screen useless (user cannot send another code), so we navigate back to root screen instead.
                navigationController.viewControllers.contains(where: { $0 is TwoFactorViewController }) {

            // this flag prevents the unnecessary showing of the "session invalidated" message to the user
            // the message is unnecessary if the user came back to the root screen intentionally
            sessionInvalidatedDueToUserGoingBackToRootController = true
            clearSessionAndPopToRootViewController(animated: true)

        } else {
            // more than 2 VC on the stack and none of them is TwoFactorViewController
            navigationController.popViewController(animated: true)
        }
    }

    private func clearSessionAndPopToRootViewController(animated: Bool,
                                                        completion: @escaping (LoginNavigationViewController) -> Void = { _ in }) {

        guard let navigationController = navigationController else { return }

        defer {
            navigationController.popToRootViewController(animated: animated) {
                completion(navigationController)
            }
        }

        // This code clears out the locally stored user session and clears the session on the BE.
        // It's a UX optimization. The app would work without it, but the user would have to tap login twice:
        // first attempt would fail and cause the session clearing, the second one would succeed.
        // By invalidating the session here we remove the need for first attempt, improving UX.
        let sessionUID = container.api.sessionUID
        guard let authDelegate = container.api.authDelegate else { return }
        guard let authCredential = authDelegate.authCredential(sessionUID: sessionUID) else { return }

        container.login.logout(credential: authCredential, completion: { _ in })

        if authCredential.isForUnauthenticatedSession {
            authDelegate.onUnauthenticatedSessionInvalidated(sessionUID: sessionUID)
        } else {
            authDelegate.onAuthenticatedSessionInvalidated(sessionUID: sessionUID)
        }

        container.api.setSessionUID(uid: "")
        container.api.acquireSessionIfNeeded(completion: { _ in })
    }
}

// MARK: - Mailbox password delegate

extension LoginCoordinator: MailboxPasswordViewControllerDelegate {
    func mailboxPasswordViewControllerDidFail(error: LoginError) {
        popAndShowError(error: error)
    }

    func mailboxPasswordViewControllerDidFinish(endLoading: @escaping () -> Void, data: LoginData) {
        finish(endLoading: endLoading, data: data)
    }

    func userDidRequestPasswordReset() {
        UIApplication.openURLIfPossible(externalLinks.passwordReset)
    }
}

// MARK: - TwoFactor delegate

extension LoginCoordinator: TwoFactorViewControllerDelegate {
    func twoFactorViewControllerDidFail(error: LoginError) {
        popAndShowError(error: error)
    }

    func twoFactorViewControllerDidFinish(endLoading: @escaping () -> Void, data: LoginData) {
        finish(endLoading: endLoading, data: data)
    }
}

private extension UIStoryboard {
    static func instantiate<T: UIViewController>(_ controllerType: T.Type) -> T {
        self.instantiate(storyboardName: "PMLogin", controllerType: controllerType)
    }
}

// MARK: - Welcome screen delegate

extension LoginCoordinator: WelcomeViewControllerDelegate {

    func userWantsToLogIn(username: String?) {
        guard let navigationController = navigationController else { return }
        navigationController.modalTransitionStyle = .coverVertical
        let login = loginViewController(username: username)
        navigationController.autoresettingNextTransitionStyle = .modalLike
        navigationController.setViewControllers([login], animated: true)
    }

    func userWantsToSignUp() {
        guard let navigationController = navigationController else { return }
        navigationController.modalTransitionStyle = .coverVertical
        navigationController.autoresettingNextTransitionStyle = .modalLike
        delegate?.userSelectedSignup(navigationController: navigationController)
    }
}

extension LoginCoordinator: AuthSessionInvalidatedDelegate {
    func sessionWasInvalidated(for sessionUID: String, isAuthenticatedSession: Bool) {
        // if this invalidation is caused due to user coming back to the root view controller of the flow,
        // see method clearSessionAndPopToRootViewController, than we don't show the info message
        guard sessionInvalidatedDueToUserGoingBackToRootController == false else {
            sessionInvalidatedDueToUserGoingBackToRootController = false
            return
        }
        guard isAuthenticatedSession else { return }
        CompletionBlockExecutor.asyncMainExecutor.execute { [weak self] in
            self?.popAndShowInfo(message: CoreString._ls_info_session_expired)
        }
    }
}
