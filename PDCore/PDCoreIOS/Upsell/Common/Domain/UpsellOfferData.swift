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

/// Everything the custom upsell modal needs to render a single offered plan.
///
/// The extraction layer produces raw values only — no localized strings and no number
/// formatting. The UI layer maps these into `Localization` strings and formats bytes,
/// durations and currency.
struct UpsellOfferData: Equatable {
    /// Technical plan id (e.g. `"drive1tb2025"`), used to perform the purchase later.
    let planName: String
    let title: Title
    let comparison: PlanComparison
    /// The selectable subscription options (typically 12-month and 1-month), yearly first.
    let cycleOptions: [CycleOption]

    enum Title: Equatable {
        /// UI: "Upgrade to {planShortTitle}".
        case upgrade(planShortTitle: String)
        /// UI: "Get {storageBytes formatted} for {price formatted}" — uses the lowest-priced discount.
        case discountedOffer(storageBytes: Int, price: Decimal, currencyCode: String)
    }
}

/// Raw free-vs-paid values backing the comparison table rows.
struct PlanComparison: Equatable {
    let freeShortTitle: String
    let paidShortTitle: String
    let freeStorageBytes: Int
    let paidStorageBytes: Int
    let freeHistoryDays: Int
    let paidHistoryDays: Int
    let freeShareWithEditAccess: Bool
    let paidShareWithEditAccess: Bool
}

struct CycleOption: Equatable {
    let cycleMonths: Int
    /// App Store product id to purchase for this cycle.
    let productID: String
    let price: Price
    /// Percentage saving for this option (e.g. `20` → "-20%"), or `nil` when there's nothing to badge.
    let discountPercent: Int?
    /// For a coupon option, the regular per-month price (StoreKit-localized) it renews at once the
    /// promotional period ends. `nil` for non-coupon options, which renew at the same price.
    let renewalPerMonthLabel: String?

    init(cycleMonths: Int, productID: String, price: Price, discountPercent: Int?, renewalPerMonthLabel: String? = nil) {
        self.cycleMonths = cycleMonths
        self.productID = productID
        self.price = price
        self.discountPercent = discountPercent
        self.renewalPerMonthLabel = renewalPerMonthLabel
    }

    enum Price: Equatable {
        /// Per-month price already localized by StoreKit (platform formatting, not app localization).
        case store(perMonthLabel: String)
        /// Coupon price straight from the payload; the UI formats it and divides by `cycleMonths` for per-month
        /// display. `code` is the coupon code redeemed via the web flow (not a StoreKit purchase).
        case coupon(code: String, amount: Decimal, currencyCode: String)
        
        var hasCoupon: Bool {
            switch self {
            case .store:
                return false
            case .coupon:
                return true
            }
        }
    }
}
