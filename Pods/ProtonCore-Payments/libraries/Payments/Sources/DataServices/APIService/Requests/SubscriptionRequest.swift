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
import ProtonCore_Log
import ProtonCore_Networking
import ProtonCore_Services

public final class SubscriptionRequest: BaseApiRequest<SubscriptionResponse> {
    private let planId: String
    private let amount: Int
    private let paymentAction: PaymentAction?

    public init(api: APIService, planId: String, amount: Int, paymentAction: PaymentAction) {
        self.planId = planId
        self.amount = amount
        self.paymentAction = paymentAction
        super.init(api: api)
    }

    public init(api: APIService, planId: String) {
        self.planId = planId
        self.amount = 0
        self.paymentAction = nil
        super.init(api: api)
    }

    override public var method: HTTPMethod { .post }

    override public var path: String { super.path + "/v4/subscription" }

    override public var parameters: [String: Any]? {
        var params: [String: Any] = ["Amount": amount, "Currency": "USD", "PlanIDs": [planId: 1], "Cycle": 12]
        guard amount != .zero, let paymentAction = paymentAction else {
            return params
        }
        params["Payment"] = ["Type": paymentAction.getType, "Details": [paymentAction.getKey: paymentAction.getValue]]
        return params
    }
}

public final class SubscriptionResponse: Response {
    var newSubscription: Subscription?

    override public func ParseResponse(_ response: [String: Any]!) -> Bool {
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

public final class GetSubscriptionRequest: BaseApiRequest<GetSubscriptionResponse> {

    override public init(api: APIService) {
        super.init(api: api)
    }
    
    override public var path: String { super.path + "/v4/subscription" }
}

public final class GetSubscriptionResponse: Response {
    var subscription: Subscription?

    override public func ParseResponse(_ response: [String: Any]!) -> Bool {
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
