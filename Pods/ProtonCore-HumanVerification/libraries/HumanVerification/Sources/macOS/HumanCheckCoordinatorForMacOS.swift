//
//  HumanCheckCoordinatorForMacOS.swift
//  ProtonCore-HumanVerification - Created on 8/20/19.
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

#if os(macOS)

import AppKit
import ProtonCoreDataModel
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonCoreUIFoundations

final class HumanCheckCoordinator {

    // MARK: - Private properties

    private let apiService: APIService
    private let clientApp: ClientApp
    private var destination: String = ""
    private var title: String?

    /// View controllers
    private let rootViewController: NSViewController?
    private var initialViewController: HumanVerifyViewController?
    private var initialHelpViewController: HVHelpViewController?

    /// View models
    private let humanVerifyViewModel: HumanVerifyViewModel

    // MARK: - Public properties

    weak var delegate: HumanCheckMenuCoordinatorDelegate?

    // MARK: - Public methods

    init(rootViewController: NSViewController?,
         apiService: APIService,
         parameters: HumanVerifyParameters,
         clientApp: ClientApp) {
        self.rootViewController = rootViewController
        self.apiService = apiService
        self.clientApp = clientApp
        self.title = parameters.title

        self.humanVerifyViewModel = HumanVerifyViewModel(api: apiService, startToken: parameters.startToken, methods: parameters.methods, clientApp: clientApp)
        self.humanVerifyViewModel.onVerificationCodeBlock = { [weak self] verificationCodeBlock in
            guard let self = self else { return }
            self.delegate?.verificationCode(tokenType: self.humanVerifyViewModel.getToken(), verificationCodeBlock: verificationCodeBlock)
        }

        if NSClassFromString("XCTest") == nil {
            if parameters.methods.count == 0 {
                self.initialHelpViewController = getHelpViewController
            } else {
                instantiateViewController()
            }
        }
    }

    func start() {
        showHumanVerification()
    }

    // MARK: - Private methods

    private func instantiateViewController() {
        self.initialViewController = instantiateVC(type: HumanVerifyViewController.self,
                                                   identifier: "HumanVerifyViewController")
        self.initialViewController?.viewModel = self.humanVerifyViewModel
        self.initialViewController?.delegate = self
        self.initialViewController?.viewTitle = title
    }

    private func showHumanVerification() {
        guard let viewController = self.initialHelpViewController ?? self.initialViewController else { return }
        if let rootViewController = rootViewController {
            rootViewController.presentAsModalWindow(viewController)
        } else {
            NSApplication.shared.keyWindow?.contentViewController?.presentAsModalWindow(viewController)
        }
    }

    private func showHelp() {
        guard let initialViewController = initialViewController else { return }
        initialViewController.present(getHelpViewController,
                                      asPopoverRelativeTo: .zero,
                                      of: initialViewController.helpButton,
                                      preferredEdge: .maxX,
                                      behavior: .transient)
    }

    private var getHelpViewController: HVHelpViewController {
        let helpViewController = instantiateVC(type: HVHelpViewController.self,
                                               identifier: "HumanCheckHelpViewController")
        helpViewController.delegate = self
        helpViewController.viewModel = HelpViewModel(url: apiService.humanDelegate?.getSupportURL(), clientApp: clientApp)
        return helpViewController
    }
}

// MARK: - HumanVerifyViewControllerDelegate

extension HumanCheckCoordinator: HumanVerifyViewControllerDelegate {
    func willReopenViewController() {
        if let initialViewController = initialViewController,
            let presentingVC = initialViewController.presentingViewController {
            presentingVC.dismiss(initialViewController)
        }
        instantiateViewController()
        showHumanVerification()
    }

    func didDismissViewController() {
        delegate?.close()
    }

    func didShowHelpViewController() {
        showHelp()
    }

    func didDismissWithError(code: Int, description: String) {
        // TODO: Missing implmenetation
    }

    func emailAddressAlreadyTakenWithError(code: Int, description: String) {
        // TODO: Missing implmenetation
    }
}

// MARK: - HVHelpViewControllerDelegate

extension HumanCheckCoordinator: HVHelpViewControllerDelegate {
    func didDismissHelpViewController() {
        if let initialHelpViewController = self.initialHelpViewController {
            initialHelpViewController.dismiss(initialHelpViewController)
        }
    }
}

extension HumanCheckCoordinator {
    private func instantiateVC<T: NSViewController>(type: T.Type, identifier: String) -> T {
        let storyboard = NSStoryboard.init(name: "HumanVerify", bundle: HVCommon.bundle)
        let customViewController = storyboard.instantiateController(withIdentifier: identifier) as! T
        return customViewController
    }
}

#endif
