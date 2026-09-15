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
import PDLocalization
import PDUIComponents

/// Maps the raw `UpsellOfferData` values into user-facing, localized strings. This is the only
/// place in the upsell feature that performs app localization and number formatting.
final class UpsellOfferFormatter {
    private let daysPerYear = 365

    func makeTitle(_ title: UpsellOfferData.Title) -> String {
        switch title {
        case .upgrade(let planShortTitle):
            return Localization.upsell_modal_title_upgrade(plan: planShortTitle)
        case .discountedOffer(let storageBytes, let price, let currencyCode):
            return Localization.upsell_modal_title_offer(
                storage: makeStorage(bytes: storageBytes),
                price: makeCurrency(price, currencyCode: currencyCode)
            )
        }
    }

    func makeCTA(planShortTitle: String) -> String {
        Localization.upsell_modal_cta(plan: planShortTitle)
    }

    func makeStorage(bytes: Int) -> String {
        ByteCountFormatter.storageSizeString(forByteCount: Int64(bytes))
    }

    func makeVersionHistory(days: Int) -> String {
        if days >= daysPerYear, days % daysPerYear == 0 {
            return Localization.upsell_modal_duration_years(years: days / daysPerYear)
        }
        return Localization.upsell_modal_duration_days(days: days)
    }

    func makeCycleLabel(months: Int) -> String {
        months == 1
            ? Localization.upsell_modal_cycle_one_month
            : Localization.upsell_modal_cycle_months(months: months)
    }

    func makeDiscountBadge(percent: Int) -> String {
        Localization.upsell_modal_discount_badge(percent: percent)
    }

    /// The App Store reviews badge, e.g. "3,000+ reviews", with the count grouped per the user's locale.
    func makeReviews(count: Int) -> String {
        let formattedCount = NumberFormatter.formatDecimalWithNoFractionDigits(number: count) ?? String(count)
        return Localization.upsell_modal_reviews(count: formattedCount)
    }

    /// The per-month price for a cycle. Store prices are already localized by StoreKit; coupon
    /// prices are formatted here and divided across the cycle for the per-month figure.
    func makePerMonthPrice(_ option: CycleOption) -> String {
        switch option.price {
        case .store(let perMonthLabel):
            return perMonthLabel
        case .coupon(_, let amount, let currencyCode):
            let perMonth = amount / Decimal(option.cycleMonths)
            return makeCurrency(perMonth, currencyCode: currencyCode)
        }
    }

    /// Renewal disclosure shown under the CTA for the selected cycle. A coupon option spells out the
    /// regular price it renews at once the promo lapses; any other option carries the generic notice.
    func makeRenewalFootnote(renewalPerMonthLabel: String?) -> String {
        guard let renewalPerMonthLabel else {
            return Localization.upsell_modal_footnote
        }
        return Localization.upsell_modal_footnote_renewal(price: renewalPerMonthLabel)
    }

    func makeCurrency(_ amount: Decimal, currencyCode: String) -> String {
        return NumberFormatter.formatPrice(amount: amount, currencyCode: currencyCode) ?? ""
    }
}
