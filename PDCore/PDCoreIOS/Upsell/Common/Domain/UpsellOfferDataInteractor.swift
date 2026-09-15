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

import Foundation
import PDCore

protocol UpsellOfferDataInteractorProtocol {
    /// Reads and parses the stored upsell payload, then resolves the offer to present: selects a
    /// plan by App Store country, fetches its cycles & prices, and applies any payload discount.
    /// Throws when no offer can be built, in which case the caller falls back to the legacy
    /// subscriptions screen.
    func execute() async throws -> UpsellOfferData
}

final class UpsellOfferDataInteractor: UpsellOfferDataInteractorProtocol {
    enum Error: Swift.Error {
        case missingPayload
        case invalidPayload
        case noEligiblePlan
        case planNotFound
        case missingCycle
    }

    private static let defaultPlanType = "DEFAULT"
    private static let monthlyCycle = 1
    private static let yearlyCycle = 12

    private let localSettings: LocalSettings
    private let upsellDataParser: UpsellDataParserProtocol
    private let plansResource: UpsellPlansResource
    private let storefrontResource: StorefrontResource

    init(
        localSettings: LocalSettings,
        upsellDataParser: UpsellDataParserProtocol,
        plansResource: UpsellPlansResource,
        storefrontResource: StorefrontResource
    ) {
        self.localSettings = localSettings
        self.upsellDataParser = upsellDataParser
        self.plansResource = plansResource
        self.storefrontResource = storefrontResource
    }

    func execute() async throws -> UpsellOfferData {
        guard let payload = localSettings.driveMobileUpsellPlanPayload else {
            throw Error.missingPayload
        }
        guard let data = upsellDataParser.parse(payload) else {
            throw Error.invalidPayload
        }

        let countryCode = await storefrontResource.currentCountryCode()
        let plan = try selectPlan(from: data.payload.paidPlans, countryCode: countryCode)
        let subscriptionPlans = try await plansResource.getSubscriptionPlans(forPlanNamed: plan.name)
        if subscriptionPlans.isEmpty {
            throw Error.planNotFound
        }

        return UpsellOfferData(
            planName: plan.name,
            title: makeTitle(for: plan),
            comparison: makeComparison(free: data.payload.freePlan, paid: plan),
            cycleOptions: try makeCycleOptions(for: plan, subscriptionPlans: subscriptionPlans)
        )
    }

    /// Picks the plan whose `type` matches the storefront country code, otherwise the `DEFAULT` plan.
    private func selectPlan(from plans: [UpsellDataV1.PaidPlan], countryCode: String?) throws -> UpsellDataV1.PaidPlan {
        if let countryCode,
           let match = plans.first(where: { $0.type.lowercased() == countryCode.lowercased() }) {
            return match
        }
        if let fallback = plans.first(where: { $0.type.lowercased() == Self.defaultPlanType.lowercased() }) {
            return fallback
        }
        throw Error.noEligiblePlan
    }

    private func makeTitle(for plan: UpsellDataV1.PaidPlan) -> UpsellOfferData.Title {
        if let lowest = plan.discounts?.min(by: { $0.price < $1.price }) {
            return .discountedOffer(
                storageBytes: plan.storageBytes,
                price: Decimal(lowest.price),
                currencyCode: lowest.currencyCode
            )
        }
        return .upgrade(planShortTitle: plan.shortTitle)
    }

    private func makeComparison(free: UpsellDataV1.FreePlan, paid: UpsellDataV1.PaidPlan) -> PlanComparison {
        PlanComparison(
            freeShortTitle: free.shortTitle,
            paidShortTitle: paid.shortTitle,
            freeStorageBytes: free.storageBytes,
            paidStorageBytes: paid.storageBytes,
            freeHistoryDays: free.historyDays,
            paidHistoryDays: paid.historyDays,
            freeShareWithEditAccess: free.shareWithEditAccess,
            paidShareWithEditAccess: paid.shareWithEditAccess
        )
    }

    private func makeCycleOptions(for plan: UpsellDataV1.PaidPlan, subscriptionPlans: [SubscriptionPlan]) throws -> [CycleOption] {
        guard let monthly = subscriptionPlans.first(where: { $0.cycleMonths == Self.monthlyCycle }),
              let yearly = subscriptionPlans.first(where: { $0.cycleMonths == Self.yearlyCycle }) else {
            throw Error.missingCycle
        }
        let yearlyCoupon = coupon(for: yearly, in: plan)
        let monthlyCoupon = coupon(for: monthly, in: plan)
        let offersCoupon = yearlyCoupon != nil || monthlyCoupon != nil

        // Yearly first. A coupon offer badges only the coupon option; otherwise the
        // comparison badge highlights the cheaper (yearly) cycle by comparing it against the monthly price.
        return [
            makeOption(for: yearly, coupon: yearlyCoupon, comparedToPerMonth: offersCoupon ? nil : monthly.perMonthPrice),
            makeOption(for: monthly, coupon: monthlyCoupon, comparedToPerMonth: nil)
        ]
    }

    private func makeOption(
        for subscriptionPlan: SubscriptionPlan,
        coupon: UpsellDataV1.Discount?,
        comparedToPerMonth: Decimal?
    ) -> CycleOption {
        if let coupon {
            let couponPerMonth = Decimal(coupon.price) / Decimal(coupon.cycleMonths)
            return CycleOption(
                cycleMonths: subscriptionPlan.cycleMonths,
                productID: subscriptionPlan.productID,
                price: .coupon(code: coupon.coupon, amount: Decimal(coupon.price), currencyCode: coupon.currencyCode),
                discountPercent: discountPercent(original: subscriptionPlan.perMonthPrice, discounted: couponPerMonth),
                // Once the coupon lapses the plan renews at its regular store price.
                renewalPerMonthLabel: subscriptionPlan.perMonthPriceLabel
            )
        }
        let percent = comparedToPerMonth.flatMap { discountPercent(original: $0, discounted: subscriptionPlan.perMonthPrice) }
        return CycleOption(
            cycleMonths: subscriptionPlan.cycleMonths,
            productID: subscriptionPlan.productID,
            price: .store(perMonthLabel: subscriptionPlan.perMonthPriceLabel),
            discountPercent: percent
        )
    }

    /// The payload coupon (discount) that applies to the given cycle, if any.
    private func coupon(for subscriptionPlan: SubscriptionPlan, in plan: UpsellDataV1.PaidPlan) -> UpsellDataV1.Discount? {
        plan.discounts?.first { $0.cycleMonths == subscriptionPlan.cycleMonths }
    }

    /// Whole-percent saving of `discounted` relative to `original`, or `nil` when there's no saving.
    private func discountPercent(original: Decimal, discounted: Decimal) -> Int? {
        guard original > 0, discounted < original else { return nil }
        let fraction = (original - discounted) / original
        let percent = Int((NSDecimalNumber(decimal: fraction).doubleValue * 100).rounded())
        return percent > 0 ? percent : nil
    }
}
