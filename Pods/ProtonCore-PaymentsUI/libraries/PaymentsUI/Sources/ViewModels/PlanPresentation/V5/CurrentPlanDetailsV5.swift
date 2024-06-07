//
//  CurrentPlanDetailsV5.swift
//  ProtonCorePaymentsUI - Created on 18.08.23.
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

#if os(iOS)

import UIKit
import ProtonCorePayments

struct CurrentPlanDetailsV5 {
    let title: String // "Proton Free"
    let description: String // "Current Plan"
    let cycleDescription: String? // "for 1 month"
    let price: String // "$0"
    let endDate: NSAttributedString? // "Current plan will expire on 10.10.24"
    let entitlements: [Entitlement]
    let hidePriceDetails: Bool
    let shouldDisplayStorageFullAlert: Bool

    enum Entitlement: Equatable {
        case progress(ProgressEntitlement)
        case description(DescriptionEntitlement)

        struct ProgressEntitlement: Equatable {
            var title: String?
            var iconUrl: URL?
            var text: String
            var min: Int
            var max: Int
            var current: Int
        }

        struct DescriptionEntitlement: Equatable {
            var text: String
            var iconUrl: URL?
            var hint: String?
        }
    }

    static func createPlan(from details: CurrentPlan.Subscription,
                           plansDataSource: PlansDataSourceProtocol?) async throws -> CurrentPlanDetailsV5 {
        var entitlements = [Entitlement]()
        var shouldDisplayStorageFullAlert = false

        for entitlement in details.entitlements {
            switch entitlement {
            case .progress(let entitlement):
                let factor: CGFloat
                if entitlement.max > 0 {
                    factor = CGFloat(entitlement.current) / CGFloat(entitlement.max)
                } else {
                    factor = 0
                }

                let multiplier = factor < 0.01 ? 0.01 : factor

                // the "storage full" alert should display if any of the storage entitlements are > 98% full
                shouldDisplayStorageFullAlert = multiplier > 0.98 || shouldDisplayStorageFullAlert

                entitlements.append(.progress(.init(
                    title: entitlement.title,
                    iconUrl: entitlement.iconName.flatMap { plansDataSource?.createIconURL(iconName: $0) },
                    text: entitlement.text,
                    min: entitlement.min,
                    max: entitlement.max,
                    current: entitlement.current
                )))
            case .description(let entitlement):
                entitlements.append(.description(.init(
                    text: entitlement.text,
                    iconUrl: plansDataSource?.createIconURL(iconName: entitlement.iconName),
                    hint: entitlement.hint
                )))
            }
        }

        var hidePriceDetails = false
        var price: String
        if let amount = details.amount, amount != 0 {
            if details.external == .apple {
                hidePriceDetails = true
                price = ""
            } else {
                price = PriceFormatter.formatPlanPrice(price: Double(amount) / 100, currencyCode: details.currency)
            }
        } else {
            price = PUITranslations.plan_details_free_price.l10n
        }

        return .init(
            title: details.title,
            description: details.description,
            cycleDescription: details.cycleDescription,
            price: price,
            endDate: endDateString(date: details.periodEnd, renew: details.willRenew ?? false),
            entitlements: entitlements,
            hidePriceDetails: hidePriceDetails,
            shouldDisplayStorageFullAlert: shouldDisplayStorageFullAlert
        )
    }

    static func endDateString(date: Int?, renew: Bool) -> NSAttributedString? {
        guard let date = date else { return nil }
        let endDate = Date(timeIntervalSince1970: .init(date))
        guard endDate.isFuture else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yy"
        let endDateString = dateFormatter.string(from: endDate)
        var string: String

        if renew {
            string = String(format: PUITranslations.plan_details_renew_auto_expired.l10n, endDateString)
        } else {
            string = String(format: PUITranslations.plan_details_renew_expired.l10n, endDateString)
        }

        return string.getAttributedString(replacement: endDateString, attrFont: .systemFont(ofSize: 13, weight: .bold))
    }
}

#endif
