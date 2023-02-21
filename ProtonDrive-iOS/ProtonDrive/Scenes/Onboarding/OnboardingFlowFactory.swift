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

import SwiftUI
import PDCore

struct OnboardingFlowFactory {
    let settings: LocalSettings
    
    let pageViewModels: [OnboardingPageViewModel] = [
        .init(imageName: "onboarding-welcome", title: "Welcome to Proton Drive", text: "The creators of Proton Mail bring you end-to-end encrypted cloud storage from Switzerland."),
        
        .init(imageName: "onboarding-files", title: "All files at your fingertips", text: "Upload and view your files on the go. Zero-access technology guarantees only you have access."),
        
        .init(imageName: "onboarding-share", title: "Secure sharing", text: "Add password protection to make your shared files even more secure."),
    
        .init(imageName: "onboarding-privacy", title: "Enjoy your private space", text: "Make your cloud storage your own. Add personal photos, ID cards, and anything that needs to stay private."),
    ]
    
    func make() -> UIViewController {
        let flow = OnboardingFlow(settings: settings, pages: pageViewModels)
        let vc = UIHostingController(rootView: flow)
        vc.modalPresentationStyle = .fullScreen
        return vc
    }
}

#if DEBUG
struct OnboardingFlowTestsManager {
    private static var testArgument: String { "--uitests" }
    private static var clearArgument: String { "--clear_all_preference" }
    private static var skipArgument: String { "--skip_onboarding" }
    
    private static let localSettings = LocalSettings(suite: Constants.appGroup)
    
    static func deafultOnboardingInTestsIfNeeded() {
        let arguments = CommandLine.arguments
        guard arguments.contains(testArgument),
              arguments.contains(clearArgument) else { return }
        
        localSettings.isOnboarded = nil
        if arguments.contains(skipArgument) {
            localSettings.isOnboarded = true
        }
    }
    
    static func skipOnboardingInTestsIfNeeded() {
        let arguments = CommandLine.arguments
        guard arguments.contains(testArgument),
              arguments.contains(clearArgument),
              arguments.contains(skipArgument) else { return }
        
        localSettings.isOnboarded = true
    }
}
#endif
