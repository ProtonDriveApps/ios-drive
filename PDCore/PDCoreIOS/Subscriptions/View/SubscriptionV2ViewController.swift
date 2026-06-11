// Copyright (c) 2025 Proton AG
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
import ProtonCorePaymentsV2
import ProtonCorePaymentsUIV2
import ProtonCoreServices
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization
import PDClient

final class SubscriptionV2ViewController: UIViewController {

    private let payments: PaymentsV2
    private let coreAPIService: ProtonCoreServices.APIService
    private let messageHander: UserMessageHandlerProtocol

    init(
        payments: PaymentsV2,
        coreAPIService: ProtonCoreServices.APIService,
        messageHander: UserMessageHandlerProtocol
    ) {
        self.payments = payments
        self.coreAPIService = coreAPIService
        self.messageHander = messageHander
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setLeadingTitleView(title: Localization.menu_text_subscription)
        view.backgroundColor = ColorProvider.BackgroundNorm

        Task {
            await showPlans()
        }
    }

    @MainActor
    private func showPlans() async {
        do {
            if !TransactionsObserver.shared.isON {
                try await startTransactionsObserver()
            }
            let paymentsViewController = try payments.availablePlansView(apiService: coreAPIService)
            add(paymentsViewController)
        } catch {
            Log.error(error: error, domain: .subscriptions)
            messageHander.handleError(PlainMessageError(error.localizedDescription))
        }
    }

    private func startTransactionsObserver() async throws {
        let manager = RemoteManager(apiService: coreAPIService)
         let configuration = TransactionsObserverConfiguration(remoteManager: manager)
        TransactionsObserver.shared.setConfiguration(configuration)
        try await TransactionsObserver.shared.start()
    }
}
