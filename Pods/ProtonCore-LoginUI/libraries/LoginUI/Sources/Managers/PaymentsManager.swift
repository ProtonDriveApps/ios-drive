//
//  PaymentsManager.swift
//  ProtonCore-Login - Created on 01/06/2021.
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

import UIKit
import ProtonCore_CoreTranslation
import ProtonCore_DataModel
import ProtonCore_Services
import ProtonCore_Payments
import ProtonCore_Login
import ProtonCore_PaymentsUI
import ProtonCore_UIFoundations

class PaymentsManager {

    private let api: APIService
    private let payments: Payments
    private var paymentsUI: PaymentsUI?
    private(set) var selectedPlan: InAppPurchasePlan?
    private var loginData: LoginData?
    private weak var existingDelegate: StoreKitManagerDelegate?
    
    init(apiService: APIService, iaps: ListOfIAPIdentifiers, shownPlanNames: ListOfShownPlanNames, clientApp: ClientApp, reportBugAlertHandler: BugAlertHandler) {
        self.api = apiService
        self.payments = Payments(inAppPurchaseIdentifiers: iaps,
                                 apiService: api,
                                 localStorage: DataStorageImpl(),
                                 reportBugAlertHandler: reportBugAlertHandler)
        payments.storeKitManager.updateAvailableProductsList { [weak self] error in
            self?.payments.storeKitManager.subscribeToPaymentQueue()
        }
        storeExistingDelegate()
        payments.storeKitManager.delegate = self
        paymentsUI = PaymentsUI(payments: payments, clientApp: clientApp, shownPlanNames: shownPlanNames)
    }
    
    func startPaymentProcess(signupViewController: SignupViewController,
                             planShownHandler: (() -> Void)?,
                             completionHandler: @escaping (Result<(), Error>) -> Void) {

        payments.storeKitManager.updateAvailableProductsList { [weak self] error in

            if let error = error {
                planShownHandler?()
                completionHandler(.failure(error))
                return
            }

            var shownHandlerCalled = false
            self?.paymentsUI?.showSignupPlans(viewController: signupViewController, completionHandler: { [weak self] reason in
                switch reason {
                case .open:
                    shownHandlerCalled = true
                    planShownHandler?()
                case .purchasedPlan(let plan):
                    self?.selectedPlan = plan
                    completionHandler(.success(()))
                case .purchaseError(let error):
                    if !shownHandlerCalled {
                        planShownHandler?()
                    }
                    completionHandler(.failure(error))
                case let .apiMightBeBlocked(message, originalError):
                    completionHandler(.failure(LoginError.apiMightBeBlocked(message: message, originalError: originalError)))
                case .close:
                    break
                case .toppedUpCredits:
                    // TODO: some popup?
                    completionHandler(.success(()))
                case .planPurchaseProcessingInProgress:
                    break
                }
            })

        }
    }
    
    func finishPaymentProcess(loginData: LoginData, completionHandler: @escaping (Result<(InAppPurchasePlan?), Error>) -> Void) {
        self.loginData = loginData
        if selectedPlan != nil {
            payments.planService.updateCurrentSubscription { [weak self] in
                self?.payments.storeKitManager.retryProcessingAllPendingTransactions { [weak self] in
                    var result: InAppPurchasePlan?
                    if self?.payments.planService.currentSubscription?.hasExistingProtonSubscription ?? false {
                        result = self?.selectedPlan
                    }
                    
                    self?.restoreExistingDelegate()
                    self?.payments.storeKitManager.unsubscribeFromPaymentQueue()
                    completionHandler(.success(result))
                }
            } failure: { error in
                completionHandler(.failure(error))
            }
        } else {
            self.restoreExistingDelegate()
            self.payments.storeKitManager.unsubscribeFromPaymentQueue()
            completionHandler(.success(nil))
        }
    }

    private func storeExistingDelegate() {
        existingDelegate = payments.storeKitManager.delegate
    }
    
    private func restoreExistingDelegate() {
        payments.storeKitManager.delegate = existingDelegate
    }
    
    func planTitle(plan: InAppPurchasePlan?) -> String? {
        guard let name = plan?.protonName else { return nil }
        return servicePlanDataService?.detailsOfServicePlan(named: name)?.titleDescription
    }
}

extension PaymentsManager: StoreKitManagerDelegate {
    var apiService: APIService? {
        return api
    }

    var tokenStorage: PaymentTokenStorage? {
        return TokenStorageImp.default
    }

    var isUnlocked: Bool {
        return true
    }

    var isSignedIn: Bool {
        return true
    }

    var activeUsername: String? { loginData?.user.name ?? loginData?.credential.userName }

    var userId: String? { loginData?.user.ID ?? loginData?.credential.userID }

    var servicePlanDataService: ServicePlanDataServiceProtocol? {
        return payments.planService
    }
}

class TokenStorageImp: PaymentTokenStorage {
    public static var `default` = TokenStorageImp()
    var token: PaymentToken?
    
    func add(_ token: PaymentToken) {
        self.token = token
    }
    
    func get() -> PaymentToken? {
        return token
    }
    
    func clear() {
        self.token = nil
    }
}
    
class DataStorageImpl: ServicePlanDataStorage {
    var servicePlansDetails: [Plan]?
    var defaultPlanDetails: Plan?
    var paymentsBackendStatusAcceptsIAP: Bool = false
    var credits: Credits?
    var currentSubscription: Subscription?
    var paymentMethods: [PaymentMethod]?
}

protocol PaymentErrorCapable: ErrorCapable {
    func showError(error: StoreKitManagerErrors)
    var bannerPosition: PMBannerPosition { get }
}

extension PaymentErrorCapable {
    func showError(error: StoreKitManagerErrors) {
        if case let .apiMightBeBlocked(message, _) = error {
            showBanner(message: message, button: CoreString._net_api_might_be_blocked_button) { [weak self] in
                self?.onDohTroubleshooting()
            }
        } else {
            guard let errorDescription = error.errorDescription else { return }
            showBanner(message: errorDescription)
        }
    }
    
    func showBanner(message: String, button: String? = nil, action: (() -> Void)? = nil) {
        showBanner(message: message, button: button, action: action, position: bannerPosition)
    }
}

extension PaymentsUIViewController: SignUpErrorCapable, LoginErrorCapable, PaymentErrorCapable {
    var bannerPosition: PMBannerPosition { .top }
}
