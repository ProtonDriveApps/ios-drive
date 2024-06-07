//
//  SubscriptionRequest.swift
//  ProtonCore-Payments - Created on 2/12/2020.
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

import Foundation
import ProtonCoreLog
import ProtonCoreNetworking
import ProtonCoreServices

typealias SubscriptionRequest = BaseApiRequest<SubscriptionResponse>

/// POST Subscription Request in API v4 – Do not use
final class V4SubscriptionRequest: SubscriptionRequest {
    private let planName: String
    private let amount: Int
    private let paymentAction: PaymentAction?
    private let cycle: Int
    private let currencyCode: String

    init(api: APIService, planName: String, amount: Int, currencyCode: String, cycle: Int, paymentAction: PaymentAction) {
        self.planName = planName
        self.amount = amount
        self.currencyCode = currencyCode
        self.paymentAction = paymentAction
        self.cycle = cycle
        super.init(api: api)
    }

    init(api: APIService, planName: String) {
        self.planName = planName
        self.amount = 0
        self.paymentAction = nil
        self.currencyCode = "USD"
        self.cycle = 12
        super.init(api: api)
    }

    override var method: HTTPMethod { .post }

    override var path: String { super.path + "/v4/subscription" }

    override var parameters: [String: Any]? {
        var params: [String: Any] = ["Amount": amount, "Currency": currencyCode, "Plans": [planName: 1], "Cycle": cycle, "External": 1]
        guard amount != .zero, let paymentAction = paymentAction else {
            return params
        }
        switch paymentAction {
        case .token(let token):
            params["PaymentToken"] = token
        case .apple:
            let paymentData: [String: Any] = ["Type": paymentAction.getType, "Details": [paymentAction.getKey: paymentAction.getValue]]
            params["Payment"] = paymentData
        }
        return params
    }
}

/// POST Subscription Request in API v5
final class V5SubscriptionRequest: SubscriptionRequest {
    private let planName: String
    private let amount: Int
    private let paymentAction: PaymentAction?
    private let cycle: Int
    private let currencyCode: String

    init(api: APIService, planName: String, amount: Int, currencyCode: String, cycle: Int, paymentAction: PaymentAction) {
        self.planName = planName
        self.amount = amount
        self.currencyCode = currencyCode
        self.paymentAction = paymentAction
        self.cycle = cycle
        super.init(api: api)
    }

    init(api: APIService, planName: String) {
        self.planName = planName
        self.amount = 0
        self.paymentAction = nil
        self.currencyCode = "USD"
        self.cycle = 12
        super.init(api: api)
    }

    override var method: HTTPMethod { .post }

    override var path: String { super.path + "/v5/subscription" }

    override var parameters: [String: Any]? {
        var params: [String: Any] = ["Amount": amount, "Currency": currencyCode, "Plans": [planName: 1], "Cycle": cycle, "External": 1]
        guard amount != .zero, let paymentAction = paymentAction else {
            return params
        }
        switch paymentAction {
        case .token(let token):
            params["PaymentToken"] = token
        case .apple:
            let paymentData: [String: Any] = ["Type": paymentAction.getType, "Details": [paymentAction.getKey: paymentAction.getValue]]
            params["Payment"] = paymentData
        }
        return params
    }
}

final class SubscriptionResponse: Response {
    var newSubscription: Subscription?

    override func ParseResponse(_ response: [String: Any]!) -> Bool {
        PMLog.debug(response.json(prettyPrinted: true))

        guard let code = response["Code"] as? Int, code == 1000 else {
            error = RequestErrors.subscriptionDecode.toResponseError(updating: error)
            return false
        }

        let subscriptionParser = GetSubscriptionResponse()
        guard subscriptionParser.ParseResponse(response) else {
            error = RequestErrors.subscriptionDecode.toResponseError(updating: error)
            return false
        }
        self.newSubscription = subscriptionParser.subscription
        return true
    }
}

typealias GetSubscriptionRequest = BaseApiRequest<GetSubscriptionResponse>

/// GET current subscription in API v4
final class V4GetSubscriptionRequest: GetSubscriptionRequest {

    override init(api: APIService) {
        super.init(api: api)
    }

    override var path: String { super.path + "/v4/subscription" }
}

/// GET current subscription in API v5
final class V5GetSubscriptionRequest: GetSubscriptionRequest {

    override init(api: APIService) {
        super.init(api: api)
    }

    override var path: String { super.path + "/v5/subscription" }
}

final class GetSubscriptionResponse: Response {
    var subscription: Subscription?

    override func ParseResponse(_ response: [String: Any]!) -> Bool {
        PMLog.debug(response.json(prettyPrinted: true))

        guard let response = response["Subscription"] as? [String: Any],
            let startRaw = response["PeriodStart"] as? Int,
            let endRaw = response["PeriodEnd"] as? Int else { return false }
        let couponCode = response["CouponCode"] as? String
        let cycle = response["Cycle"] as? Int
        let amount = response["Amount"] as? Int
        let currency = response["Currency"] as? String
        guard let plansResponse = response["Plans"] else { return false }
        let (plansParsed, plans) = decodeResponse(plansResponse, to: [Plan].self, errorToReturn: .subscriptionDecode)
        guard plansParsed else { return false }
        let start = Date(timeIntervalSince1970: Double(startRaw))
        let end = Date(timeIntervalSince1970: Double(endRaw))
        self.subscription = Subscription(start: start, end: end, planDetails: plans, couponCode: couponCode, cycle: cycle, amount: amount, currency: currency)
        return true
    }
}
