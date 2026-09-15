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
import PDClient
import PDCore

/// The coupon, plan, billing cycle and currency to pre-select in the web checkout. `plan` is the technical
/// plan name from the upsell payload (Feature flag); `cycle` is the number of months ("1" or "12");
/// `currency` is the ISO code of the coupon being redeemed.
struct UpsellCheckoutInput: Equatable {
    let coupon: String
    let plan: String
    let cycle: String
    let currency: String
}

protocol UpsellCouponURLFactoryProtocol {
    /// Builds the authenticated web URL that redeems `coupon` for the given checkout `state`,
    /// carrying the forked-session credentials.
    func makeURL(input: UpsellCheckoutInput, sessionData: AuthenticatedWebSessionData) throws -> URL
}

enum UpsellCouponURLFactoryError: Error {
    case invalidHost
    case invalidURL
}

/// Builds the account web URL that redeems an upsell coupon for a forked session. Mirrors
/// `ProtonFileAuthenticatedURLFactory`: the session selector and key travel in the URL fragment.
final class UpsellCouponURLFactory: UpsellCouponURLFactoryProtocol {
    private let configuration: APIService.Configuration

    init(configuration: APIService.Configuration) {
        self.configuration = configuration
    }

    func makeURL(input: UpsellCheckoutInput, sessionData: AuthenticatedWebSessionData) throws -> URL {
        guard var urlComponents = URLComponents(string: configuration.baseOrigin) else {
            throw UpsellCouponURLFactoryError.invalidHost
        }
        guard let host = urlComponents.host, !host.isEmpty else {
            throw UpsellCouponURLFactoryError.invalidHost
        }

        urlComponents.host = "account." + host
        urlComponents.path = "/lite"
        let queryItems: [URLQueryItem] = [
            .init(name: "action", value: "subscribe-account"),
            .init(name: "redirect", value: "protondrive://"),
            .init(name: "start", value: "checkout"),
            .init(name: "disablePlanSelector", value: "true"),
            .init(name: "disableCycleSelector", value: "true"),
            .init(name: "hideClose", value: "true"),
            .init(name: "plan", value: input.plan),
            .init(name: "cycle", value: input.cycle),
            .init(name: "coupon", value: input.coupon),
            .init(name: "currency", value: input.currency)
        ]
        let fragment = "selector=\(sessionData.selector)"
        urlComponents.queryItems = queryItems
        urlComponents.fragment = fragment

        guard let url = urlComponents.url else {
            throw UpsellCouponURLFactoryError.invalidURL
        }

        return url
    }
}
