//
//  TokenRequest.swift
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

public final class TokenRequest: BaseApiRequest<TokenResponse> {
    private let amount: Int
    private let receipt: String

    public init (api: APIService, amount: Int, receipt: String) {
        self.amount = amount
        self.receipt = receipt
        super.init(api: api)
    }

    override public var method: HTTPMethod { .post }

    override public var isAuth: Bool { false }

    override public var path: String { super.path + "/v4/tokens" }

    override public var parameters: [String: Any]? {
        let paymentDict: [String: Any]
        if let card = ProtonCore_Payments.TemporaryHacks.testCardForPayments {
            paymentDict = [
                "Type": "card",
                "Details": card
            ]
        } else {
            paymentDict = [
                "Type": "apple",
                "Details": ["Receipt": receipt]
            ]
        }
        return ["Amount": amount, "Currency": "USD", "Payment": paymentDict]
    }
}

public final class TokenResponse: Response {
    var paymentToken: PaymentToken?

    override public func ParseResponse(_ response: [String: Any]!) -> Bool {
        PMLog.debug(response.json(prettyPrinted: true))
        let (result, token) = decodeResponse(response as Any, to: PaymentToken.self, errorToReturn: .tokenDecode)
        self.paymentToken = token
        return result
    }
}
