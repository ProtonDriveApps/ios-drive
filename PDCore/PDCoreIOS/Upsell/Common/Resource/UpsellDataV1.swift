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

struct UpsellDataV1: Decodable {
    struct Payload: Decodable {
        let freePlan: FreePlan
        let paidPlans: [PaidPlan]
    }

    struct FreePlan: Decodable {
        let shortTitle: String
        let storageBytes: Int
        let historyDays: Int
        let shareWithEditAccess: Bool
    }

    struct PaidPlan: Decodable {
        let type: String
        let name: String
        let shortTitle: String
        let cycleMonths: Int
        let storageBytes: Int
        let storageIncreaseFactor: Int
        let historyDays: Int
        let shareWithEditAccess: Bool
        let discounts: [Discount]?
    }

    struct Discount: Decodable {
        let coupon: String
        let currencyCode: String
        let cycleMonths: Int
        let price: Double
    }

    let schemaVersion: Int
    let payload: Payload
}
