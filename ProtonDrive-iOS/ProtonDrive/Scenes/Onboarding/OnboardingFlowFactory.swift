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

import PDCore
import PDLocalization
import SwiftUI

struct OnboardingFlowFactory {
    let pageViewModels: [OnboardingPageViewModel] = [
        .init(imageName: "onboarding-photo", title: Localization.onboarding_photo_title, text: Localization.onboarding_photo_text),
        .init(imageName: "onboarding-files", title: Localization.onboarding_file_title, text: Localization.onboarding_file_text),
        .init(imageName: "onboarding-share", title: Localization.onboarding_share_title, text: Localization.onboarding_share_text),
    ]
    
    func makeIfNeeded(settings: LocalSettings) -> UIViewController? {
        guard !settings.isOnboarded else {
            return nil
        }
        guard settings.isB2BUser != true else {
            return nil
        }
        return make(settings: settings)
    }
    
    private func make(settings: LocalSettings) -> UIViewController {
        let flow = OnboardingFlow(settings: settings, pages: pageViewModels)
        let vc = UIHostingController(rootView: flow)
        vc.modalPresentationStyle = .fullScreen
        return vc
    }
}
