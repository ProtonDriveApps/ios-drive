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

/// The fully-formatted, localized data rendered on the upsell page. This is a plain value type with
/// no formatting logic of its own — `UpsellOfferViewDataFactory` maps the domain model into it.
struct UpsellOfferContent: Equatable {
    struct ComparisonRow: Equatable, Identifiable {
        let label: String
        let free: Cell
        let paid: Cell
        var id: String { label }

        enum Cell: Equatable {
            case text(String)
            case available(Bool)
        }
    }

    struct CycleOptionDisplay: Equatable, Identifiable {
        let index: Int
        let cycleLabel: String
        let monthLabel: String
        let priceLabel: String
        let discountBadge: String?
        /// Renewal disclosure shown under the CTA while this option is selected. Coupon options
        /// spell out the post-promo renewal rate; other options carry the generic recurring notice.
        let footnote: String
        var id: Int { index }
    }

    let title: String
    let subtitle: String
    let awardTitle: String
    let reviewsBadge: String
    let freeColumnTitle: String
    let paidColumnTitle: String
    let comparisonRows: [ComparisonRow]
    let chooseSubscriptionTitle: String
    let cycleOptions: [CycleOptionDisplay]
    let ctaTitle: String
    /// Shown when a purchase is accepted but awaiting external approval (e.g. Ask to Buy).
    let pendingMessage: String
    let closeAccessibilityLabel: String
}
