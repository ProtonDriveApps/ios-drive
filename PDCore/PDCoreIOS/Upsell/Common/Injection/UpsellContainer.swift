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

import PDCore
import ProtonCoreAuthentication
import ProtonCoreServices
import SwiftUI
import UIKit

@MainActor
public final class UpsellContainer {
    public struct Dependencies {
        public let tower: Tower
        public let featureFlagsController: FeatureFlagsControllerProtocol
        public let userInfoController: UserInfoController

        public init(
            tower: Tower,
            featureFlagsController: FeatureFlagsControllerProtocol,
            userInfoController: UserInfoController
        ) {
            self.tower = tower
            self.featureFlagsController = featureFlagsController
            self.userInfoController = userInfoController
        }
    }

    private let dependencies: Dependencies
    let upsellController: UpsellControllerProtocol

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
        upsellController = UpsellController(
            featureFlagsController: dependencies.featureFlagsController,
            userInfoController: dependencies.userInfoController,
            loadInteractor: UpsellOfferDataInteractor(
                localSettings: dependencies.tower.localSettings,
                upsellDataParser: UpsellDataParser(),
                plansResource: PlansComposerUpsellPlansResource(apiService: dependencies.tower.networking),
                storefrontResource: StoreKitStorefrontResource()
            )
        )
    }

    func makeRootViewController(coordinator: UpsellCoordinatorProtocol) -> UpsellRootViewController {
        let viewModel = UpsellRootViewModel(controller: upsellController, coordinator: coordinator)
        return UpsellRootViewController(viewModel: viewModel)
    }

    func makeModalViewController(offer: UpsellOfferData, coordinator: UpsellCoordinatorProtocol) -> UIViewController {
        let viewModel = UpsellOfferViewModel(
            offer: offer,
            purchaseResource: ProtonUpsellPurchaseResource(apiService: dependencies.tower.networking),
            couponInteractor: makeCouponInteractor(),
            coordinator: coordinator
        )
        return UIHostingController(rootView: UpsellOfferView(viewModel: viewModel))
    }

    /// Wires the web-session fork + URL factory used to redeem a coupon cycle on the web.
    private func makeCouponInteractor() -> UpsellCouponInteractorProtocol {
        let tower = dependencies.tower
        let authenticator = Authenticator(api: tower.networking)
        let selectorRepository = ChildSessionSelectorRepository(sessionStorage: tower.sessionVault, authenticator: authenticator)
        let webSessionInteractor = AuthenticatedWebSessionInteractor(
            sessionStore: tower.sessionVault,
            selectorRepository: selectorRepository,
            encryptionResource: CryptoKitAESGCMEncryptionResource(),
            encodingResource: FoundationEncodingResource()
        )
        return UpsellCouponInteractor(
            webSessionInteractor: webSessionInteractor,
            urlFactory: UpsellCouponURLFactory(configuration: tower.api.configuration)
        )
    }
}
