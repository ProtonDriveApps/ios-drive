//
//  HumanCheckHelperForMacOS.swift
//  ProtonCore-HumanVerification - Created on 2/1/16.
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
import ProtonCoreAPIClient
import ProtonCoreNetworking
import ProtonCoreServices
import enum ProtonCoreDataModel.ClientApp

public class HumanCheckHelper: HumanVerifyDelegate {
    private let rootViewController: NSViewController?
    public weak var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    public weak var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    private let apiService: APIService
    private let supportURL: URL
    private var verificationCompletion: ((HumanVerifyFinishReason) -> Void)?
    private var humanCheckCoordinator: HumanCheckCoordinator?
    private let clientApp: ClientApp

    public init(apiService: APIService,
                supportURL: URL? = nil,
                viewController: NSViewController? = nil,
                clientApp: ClientApp) {
        self.apiService = apiService
        self.supportURL = supportURL ?? HVCommon.defaultSupportURL(clientApp: clientApp)
        self.rootViewController = viewController
        self.clientApp = clientApp
    }

    public func onHumanVerify(parameters: HumanVerifyParameters, currentURL: URL?, completion: (@escaping (HumanVerifyFinishReason) -> Void)) {

        // check if payment token exists
        if let paymentToken = paymentDelegateForLoginAndSignup?.paymentToken {
            let client = TestApiClient(api: self.apiService)
            let route = client.createHumanVerifyRoute(destination: nil, type: VerifyMethod(predefinedMethod: .payment), token: paymentToken)
            // retrigger request and use header with payment token
            completion(.verification(header: route.header, verificationCodeBlock: { result, _, verificationFinishBlock in
                self.paymentDelegateForLoginAndSignup?.paymentTokenStatusChanged(status: result == true ? .success : .fail)
                if result {
                    verificationFinishBlock?()
                } else {
                    // if request still has an error, start human verification UI
                    self.startMenuCoordinator(parameters: parameters, completion: completion)
                }
            }))
        } else {
            // start human verification UI
            startMenuCoordinator(parameters: parameters, completion: completion)
        }
    }

    private func startMenuCoordinator(parameters: HumanVerifyParameters, completion: (@escaping (HumanVerifyFinishReason) -> Void)) {
        prepareCoordinator(parameters: parameters)
        responseDelegateForLoginAndSignup?.onHumanVerifyStart()
        verificationCompletion = completion
    }

    private func prepareCoordinator(parameters: HumanVerifyParameters) {
        humanCheckCoordinator = HumanCheckCoordinator(rootViewController: rootViewController, apiService: apiService, parameters: parameters, clientApp: clientApp)
        humanCheckCoordinator?.delegate = self
        humanCheckCoordinator?.start()
    }

    public func getSupportURL() -> URL {
        return supportURL
    }
}

extension HumanCheckHelper: HumanCheckMenuCoordinatorDelegate {
    func verificationCode(tokenType: TokenType, verificationCodeBlock: @escaping (SendVerificationCodeBlock)) {
        let client = TestApiClient(api: self.apiService)
        let route = client.createHumanVerifyRoute(destination: tokenType.destination, type: tokenType.verifyMethod, token: tokenType.token)
        verificationCompletion?(.verification(header: route.header, verificationCodeBlock: { result, error, finish in
            verificationCodeBlock(result, error, finish)
            if result {
                self.responseDelegateForLoginAndSignup?.onHumanVerifyEnd(result: .success)
            }
        }))
    }

    func close() {
        verificationCompletion?(.close)
        self.responseDelegateForLoginAndSignup?.onHumanVerifyEnd(result: .cancel)
    }

    func closeWithError(code: Int, description: String) {
        verificationCompletion?(.closeWithError(code: code, description: description))
        self.responseDelegateForLoginAndSignup?.onHumanVerifyEnd(result: .cancel)
    }
}

#endif
