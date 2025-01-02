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

#if DEBUG
import Foundation
import PDCore

final class UITestsPopulatedViewModelDecorator: PopulateViewModelProtocol {
    private let viewModel: PopulateViewModelProtocol
    private let localSettings: LocalSettings

    init(viewModel: PopulateViewModelProtocol, localSettings: LocalSettings) {
        self.viewModel = viewModel
        self.localSettings = localSettings
    }
    
    func updateLocalSettingForUITest() {
        if DebugConstants.commandLineContains(flags: [.uiTests, .clearDefaultTab]) {
            localSettings.clearDefaultHomeTab()
            DebugConstants.removeCommandLine(flags: [.clearDefaultTab])
        }
        
        if DebugConstants.commandLineContains(flags: [.uiTests, .filesAsDefaultTab]) {
            localSettings.defaultHomeTabTag = TabBarItem.files.tag
            DebugConstants.removeCommandLine(flags: [.filesAsDefaultTab])
        }
    }

    @MainActor
    func populate() async throws {
        OnboardingFlowTestsManager.setFlagForUITest(localSettings: localSettings)
        OneDollarUpsellFlowTestsManager.setFlagForUITest(localSettings: localSettings)
        PhotoUpsellFlowTestsManager.setFlagForUITest(localSettings: localSettings)
        NewFeaturePromoteFlowTestsManager.setFlagForUITest(localSettings: localSettings)
        
        updateLocalSettingForUITest()
        try await viewModel.populate()
    }
}

struct OnboardingFlowTestsManager {
    static func setFlagForUITest(localSettings: LocalSettings) {
        guard DebugConstants.commandLineContains(flags: [.uiTests]) else { return }
        
        if DebugConstants.commandLineContains(flags: [.defaultOnboarding]) {
            localSettings.isOnboarded = false
            DebugConstants.removeCommandLine(flags: [.defaultOnboarding])
        }
        
        if DebugConstants.commandLineContains(flags: [.skipOnboarding]) {
            localSettings.isOnboarded = true
            DebugConstants.removeCommandLine(flags: [.skipOnboarding])
        }
    }
}

struct NewFeaturePromoteFlowTestsManager {
    static func setFlagForUITest(localSettings: LocalSettings) {
        guard DebugConstants.commandLineContains(flags: [.uiTests]) else { return }
        
        if DebugConstants.commandLineContains(flags: [.defaultNewFeaturePromote]) {
            localSettings.clearPromotedNewFeatures()
            DebugConstants.removeCommandLine(flags: [.defaultNewFeaturePromote])
        }
        
        if DebugConstants.commandLineContains(flags: [.skipNewFeaturePromote]) {
            localSettings.append(promotedNewFeatures: NewFeature.sortedCases.map(\.rawValue))
        }
    }
}
#endif
