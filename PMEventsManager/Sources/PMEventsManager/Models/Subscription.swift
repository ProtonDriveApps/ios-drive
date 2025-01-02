// Copyright (c) 2023 Proton AG
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
import ProtonCorePayments

// Can not reuse from ProtonCorePayments because object there does not use Codable for parsing of BE response

public struct Subscription: Codable {
    public let ID: String
    public let invoiceID: String?
    public let cycle: Int
    public let periodStart: Int
    public let periodEnd: Int
    public let couponCode: String?
    public let currency: String
    public let amount: Int
    public let plans: [Plan]
    public let renew: Int
    
    public init(ID: String, invoiceID: String?, cycle: Int, periodStart: Int, periodEnd: Int, couponCode: String?, currency: String, amount: Int, plans: [Plan], renew: Int) {
        self.ID = ID
        self.invoiceID = invoiceID
        self.cycle = cycle
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.couponCode = couponCode
        self.currency = currency
        self.amount = amount
        self.plans = plans
        self.renew = renew
    }
}
