// Copyright (c) 2026 Proton AG
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

import Foundation
import ProtonCorePaymentsV2
import ProtonCoreServices
import StoreKit

/// Performs the purchase of a single product through ProtonCore's `ProtonPlansManager`. The
/// already-bootstrapped `TransactionsObserver` validates the transaction with the backend; we
/// ensure it is running defensively in case the modal is reached before bootstrap completed.
final class ProtonUpsellPurchaseResource: UpsellPurchaseResource {
    private struct ProductNotFound: Error {}

    private let apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func purchase(productID: String) async throws -> UpsellPurchaseOutcome {
        try await startTransactionsObserverIfNeeded()

        guard let product = try await Product.products(for: [productID]).first else {
            throw ProductNotFound()
        }

        let manager = ProtonPlansManager(remoteManager: RemoteManager(apiService: apiService))
        do {
            let composedPlan = try await manager.purchase(product)
            // Non-nil → finished successfully; nil → StoreKit reported the purchase as pending.
            return composedPlan == nil ? .pending : .purchased
        } catch ProtonPlansManagerError.transactionCancelledByUser {
            return .cancelled
        }
    }

    private func startTransactionsObserverIfNeeded() async throws {
        guard !TransactionsObserver.shared.isON else { return }
        let configuration = TransactionsObserverConfiguration(remoteManager: RemoteManager(apiService: apiService))
        TransactionsObserver.shared.setConfiguration(configuration)
        try await TransactionsObserver.shared.start()
    }
}
