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

protocol UpsellPlansResource {
    /// Fetches the purchasable cycles for the plan with the given technical `name`.
    func getSubscriptionPlans(forPlanNamed name: String) async throws -> [SubscriptionPlan]
}

/// Fetches plans through ProtonCore's `PlansComposer`, which already resolves available
/// plans via `RemoteManager` and matches them to StoreKit products (localized prices).
final class PlansComposerUpsellPlansResource: UpsellPlansResource {
    private let apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func getSubscriptionPlans(forPlanNamed name: String) async throws -> [SubscriptionPlan] {
        let composer = PlansComposer(remoteManager: RemoteManager(apiService: apiService))
        let composedPlans = try await composer.fetchAvailablePlans()
        return composedPlans
            .filter { $0.plan.name == name }
            .map { plan in
                SubscriptionPlan(
                    cycleMonths: plan.instance.cycle,
                    productID: plan.product.id,
                    perMonthPriceLabel: plan.pricePerMonthLabel,
                    perMonthPrice: plan.storePricePerMonth
                )
            }
    }
}
