// Copyright (c) 2024 Proton AG
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
import PDCoreIOS

protocol RatingBoosterFlowControllerProtocol {
    func navigationDidHappen()
}

/// Request review popup from StoreKit when conditions fulfill
/// Condition:
/// - has 2 FF, `hasRatingIOSDrive` and `hasRatingBooster`
/// - Navigation happen, in another word, we want to present review popup in the second view
final class RatingBoosterFlowController: RatingBoosterFlowControllerProtocol {
    private let coordinator: RatingBoosterCoordinatorProtocol
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let localSettings: LocalSettings
    private let repository: DisableLegacyRatingRepositoryProtocol
    private var hasInitialized = false
    
    init(
        coordinator: RatingBoosterCoordinatorProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol,
        localSettings: LocalSettings,
        repository: DisableLegacyRatingRepositoryProtocol
    ) {
        self.coordinator = coordinator
        self.featureFlagsController = featureFlagsController
        self.localSettings = localSettings
        self.repository = repository
    }
    
    func navigationDidHappen() {
        guard hasInitialized else {
            hasInitialized = true
            return
        }
        guard
            featureFlagsController.hasRatingBooster,
            featureFlagsController.hasRatingIOSDrive
        else { return }
        presentRatingPopup()
    }
    
    private func presentRatingPopup() {
        coordinator.presentRatingPopup()
        repository.disableRatingIOS()
        localSettings.ratingIOSDrive = false
    }
}
