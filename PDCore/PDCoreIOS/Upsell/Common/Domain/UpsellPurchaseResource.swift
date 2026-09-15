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

enum UpsellPurchaseOutcome {
    /// The purchase completed; the backend subscription is finalized in the background by the transactions observer.
    case purchased
    /// StoreKit accepted the purchase but it is awaiting external action (e.g. Ask to Buy).
    case pending
    /// The user dismissed the StoreKit purchase sheet.
    case cancelled
}

protocol UpsellPurchaseResource {
    /// Purchases the given App Store product. Throws on a genuine purchase failure (the caller surfaces an error).
    func purchase(productID: String) async throws -> UpsellPurchaseOutcome
}
