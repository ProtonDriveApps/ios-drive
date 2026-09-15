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

protocol UpsellControllerProtocol {
    func loadUpsell() async -> UpsellRootData
}

final class UpsellController: UpsellControllerProtocol {
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let userInfoController: UserInfoController
    private let loadInteractor: UpsellOfferDataInteractorProtocol

    init(
        featureFlagsController: FeatureFlagsControllerProtocol,
        userInfoController: UserInfoController,
        loadInteractor: UpsellOfferDataInteractorProtocol
    ) {
        self.featureFlagsController = featureFlagsController
        self.userInfoController = userInfoController
        self.loadInteractor = loadInteractor
    }

    func loadUpsell() async -> UpsellRootData {
        guard isEligible() else {
            return .fallbackToSubscriptions
        }
        do {
            let offer = try await loadInteractor.execute()
            return .showCustomUpsell(offer)
        } catch {
            return .fallbackToSubscriptions
        }
    }

    private func isEligible() -> Bool {
        guard let user = userInfoController.currentUser else { return false }
        return featureFlagsController.hasPaymentsV2
            && featureFlagsController.hasCustomUpsellModal
            && !user.isPaid
    }
}
