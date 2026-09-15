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
import PDCore
import PDCoreIOS
import Combine

final class DebugModeSettingsViewModel: ObservableObject {
    @Published var isDebugModeEnabled: Bool {
        didSet {
            Log.info("Will set debug mode to: \(isDebugModeEnabled)", domain: .logs)
            localSettings.debugModeEnabled = isDebugModeEnabled
        }
    }

    let sdkLibraryVersion: String?

    private let localSettings: LocalSettings
    private let coordinator: DebugModeSettingsCoordinator
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let notificationCenter: NotificationCenter
    private(set) var experimentalFeatures: [ExperimentalFeatures: Bool] = [:]

    init(
        localSettings: LocalSettings,
        coordinator: DebugModeSettingsCoordinator,
        notificationCenter: NotificationCenter = .default,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) {
        self.localSettings = localSettings
        self.isDebugModeEnabled = localSettings.debugModeEnabled
        self.featureFlagsController = featureFlagsController
        self.coordinator = coordinator
        self.notificationCenter = notificationCenter
        self.sdkLibraryVersion = BundleInfo.value(for: .sdkVersion)
        if !featureFlagsController.hasRefactoredFinderViewByDefault {
            experimentalFeatures[.finderImprovement] = localSettings.iOSRefactoredFinder
        }
    }

    func didTapDiagnostics() {
        coordinator.showStorageDiagnostics()
    }

    func didTapPhotoDiagnostics() {
        coordinator.presentPhotoBackupDiagnostics()
    }

    func toggleExperimentalFeature(_ feature: ExperimentalFeatures, newValue: Bool) {
        if experimentalFeatures[feature] == newValue { return }
        switch feature {
        case .finderImprovement:
            localSettings.iOSRefactoredFinder = newValue
            notificationCenter.post(name: .restartApplication)
        }
    }
}

extension DebugModeSettingsViewModel {
    enum ExperimentalFeatures: String {
        case finderImprovement = "Finder improvement"
    }
}
