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
import PDCore

protocol UpsellCouponInteractorProtocol {
    /// Resolves the authenticated web URL that redeems the coupon for the given checkout `input`.
    /// A coupon cycle is purchased on the web (not via StoreKit), so this forks the session and
    /// builds the hand-off URL.
    func execute(input: UpsellCheckoutInput) async throws -> URL
}

/// Forks an authenticated web session and hands the coupon to `UpsellCouponURLFactory` to build the
/// redemption URL the caller then opens.
final class UpsellCouponInteractor: UpsellCouponInteractorProtocol {
    private let webSessionInteractor: AuthenticatedWebSessionInteractorProtocol
    private let urlFactory: UpsellCouponURLFactoryProtocol

    init(
        webSessionInteractor: AuthenticatedWebSessionInteractorProtocol,
        urlFactory: UpsellCouponURLFactoryProtocol
    ) {
        self.webSessionInteractor = webSessionInteractor
        self.urlFactory = urlFactory
    }

    func execute(input: UpsellCheckoutInput) async throws -> URL {
        let sessionData = try await webSessionInteractor.execute(type: .webAccountLite)
        return try urlFactory.makeURL(input: input, sessionData: sessionData)
    }
}
