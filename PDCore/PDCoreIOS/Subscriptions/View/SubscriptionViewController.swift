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

import UIKit
import PDCore
import ProtonCoreFeatureFlags
import ProtonCorePaymentsUI
import ProtonCorePayments
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization

final class SubscriptionViewController: UIViewController, StoreKitManagerDelegate {

    private let payments: Payments
    private let paymentsUI: PaymentsUI

    // MARK: - StoreKitManagerDelegate

    var tokenStorage: PaymentTokenStorage? {
        TokenStorage.default
    }

    var isUnlocked: Bool

    var isSignedIn: Bool

    var activeUsername: String?

    var userId: String?

    init(isUnlocked: Bool,
         isSignedIn: Bool,
         userId: String?,
         activeUsername: String?,
         payments: Payments) {
        self.isUnlocked = isUnlocked
        self.isSignedIn = isSignedIn
        self.userId = userId
        self.activeUsername = activeUsername
        self.payments = payments
        self.paymentsUI = PaymentsUI(
            payments: payments,
            clientApp: .drive,
            shownPlanNames: SubscriptionConstants.shownPlanNames,
            customization: .empty
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        setLeadingTitleView(title: Localization.menu_text_subscription)

        view.backgroundColor = ColorProvider.BackgroundNorm

        payments.storeKitManager.delegate = self
        payments.storeKitManager.subscribeToPaymentQueue()
        
        if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.dynamicPlan) {
            showCurrentPlan()
        } else {
            let indicator = makeActivityIndicator()
            addIndicatorToCenter(indicator)
            payments.storeKitManager.updateAvailableProductsList { [weak self] _ in
                indicator.removeFromSuperview()
                self?.showCurrentPlan()
            }
        }
    }

    private func makeActivityIndicator() -> UIView {
        // TODO: Payment setup may take time before its UI is showed. See DRVIOS-1668
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }
    
    private func addIndicatorToCenter(_ indicator: UIView) {
        view.addSubview(indicator)
        indicator.centerXInSuperview()
        indicator.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: 10).isActive = true
    }
    
    private func showCurrentPlan() {
        paymentsUI.showCurrentPlan(presentationType: .none, backendFetch: true) { [unowned self] result in
            switch result {
            case .open(let vc, let opened) where opened == false:
                self.addChild(vc)
                self.view.addSubview(vc.view)
            default:
                break
            }
        }
    }
    
}

private extension SubscriptionViewController {

    class TokenStorage: PaymentTokenStorage {
        public static var `default` = TokenStorage()

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
}
