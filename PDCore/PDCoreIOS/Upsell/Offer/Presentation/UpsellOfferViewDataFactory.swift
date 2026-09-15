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

import PDCore
import PDLocalization

/// Maps the upsell domain model into ready-to-render `UpsellOfferContent`. It owns all formatting and
/// localization for the page, so views and the view model deal only with plain, formatted strings.
struct UpsellOfferViewDataFactory {
    /// Approximate App Store review count advertised on the page.
    private let reviewsCount: Int
    private let formatter: UpsellOfferFormatter

    init(reviewsCount: Int = 3000, formatter: UpsellOfferFormatter = UpsellOfferFormatter()) {
        self.reviewsCount = reviewsCount
        self.formatter = formatter
    }

    func makeContent(from offer: UpsellOfferData) -> UpsellOfferContent {
        UpsellOfferContent(
            title: formatter.makeTitle(offer.title),
            subtitle: Localization.upsell_modal_subtitle,
            awardTitle: Localization.upsell_modal_badge_privacy,
            reviewsBadge: formatter.makeReviews(count: reviewsCount),
            freeColumnTitle: offer.comparison.freeShortTitle,
            paidColumnTitle: offer.comparison.paidShortTitle,
            comparisonRows: makeComparisonRows(offer.comparison),
            chooseSubscriptionTitle: Localization.upsell_modal_choose_subscription,
            cycleOptions: makeCycleOptions(offer.cycleOptions),
            ctaTitle: formatter.makeCTA(planShortTitle: offer.comparison.paidShortTitle),
            pendingMessage: Localization.upsell_modal_pending_message,
            closeAccessibilityLabel: Localization.general_close
        )
    }

    private func makeComparisonRows(_ comparison: PlanComparison) -> [UpsellOfferContent.ComparisonRow] {
        [
            UpsellOfferContent.ComparisonRow(
                label: Localization.upsell_modal_row_storage,
                free: .text(formatter.makeStorage(bytes: comparison.freeStorageBytes)),
                paid: .text(formatter.makeStorage(bytes: comparison.paidStorageBytes))
            ),
            UpsellOfferContent.ComparisonRow(
                label: Localization.upsell_modal_row_version_history,
                free: .text(formatter.makeVersionHistory(days: comparison.freeHistoryDays)),
                paid: .text(formatter.makeVersionHistory(days: comparison.paidHistoryDays))
            ),
            UpsellOfferContent.ComparisonRow(
                label: Localization.upsell_modal_row_share_edit,
                free: .available(comparison.freeShareWithEditAccess),
                paid: .available(comparison.paidShareWithEditAccess)
            )
        ]
    }

    private func makeCycleOptions(_ options: [CycleOption]) -> [UpsellOfferContent.CycleOptionDisplay] {
        options.enumerated().map { index, option in
            UpsellOfferContent.CycleOptionDisplay(
                index: index,
                cycleLabel: formatter.makeCycleLabel(months: option.cycleMonths),
                monthLabel: Localization.upsell_modal_price_per_month,
                priceLabel: formatter.makePerMonthPrice(option),
                discountBadge: option.discountPercent.map(formatter.makeDiscountBadge(percent:)),
                footnote: formatter.makeRenewalFootnote(renewalPerMonthLabel: option.renewalPerMonthLabel)
            )
        }
    }
}
