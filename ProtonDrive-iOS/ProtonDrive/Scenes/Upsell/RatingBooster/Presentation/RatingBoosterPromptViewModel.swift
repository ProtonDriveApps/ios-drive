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

import Foundation
import PDLocalization

struct RatingBoosterViewData {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let hasHeart: Bool
    let secondaryButtonTitle: String

    init(step: RatingBoosterPromptViewModel.Step) {
        switch step {
        case .enjoying:
            title = Localization.rating_booster_enjoying_title
            message = Localization.rating_booster_enjoying_description
            primaryButtonTitle = Localization.rating_booster_like_it_button
            hasHeart = true
            secondaryButtonTitle = Localization.rating_booster_could_be_better_button
        case .help:
            title = Localization.rating_booster_help_title
            message = Localization.rating_booster_help_description
            primaryButtonTitle = Localization.rating_booster_contact_us_button
            hasHeart = false
            secondaryButtonTitle = Localization.general_not_now
        }
    }
}

@MainActor
final class RatingBoosterPromptViewModel: ObservableObject {
    enum Step {
        /// "Enjoying Proton Drive?" — I like it / Could be better.
        case enjoying
        /// "Help us enhance your experience" — Contact us / Not now.
        case help
    }

    let viewData: RatingBoosterViewData

    private let step: Step
    private weak var coordinator: RatingBoosterCoordinatorProtocol?

    init(step: Step, coordinator: RatingBoosterCoordinatorProtocol) {
        self.step = step
        self.coordinator = coordinator
        self.viewData = RatingBoosterViewData(step: step)
    }

    func primaryButtonTapped() {
        switch step {
        case .enjoying:
            coordinator?.openNativeReview()
        case .help:
            coordinator?.openBugReport()
        }
    }

    func secondaryButtonTapped() {
        switch step {
        case .enjoying:
            coordinator?.openHelp()
        case .help:
            coordinator?.close()
        }
    }
}
