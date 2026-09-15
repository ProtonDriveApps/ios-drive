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

import Combine
import Foundation
import PDCore
import UIKit

public protocol UpgradeRequirementBannerObserving {
    func subscribeToUpgradeRequirement(currentTab: TabBarItem?) -> AnyPublisher<UpgradeRequirementLevel, Never>
}

public protocol UpgradeRequirementHandling {
    func closeUpgradeHintBanner()
    func openAppStore()
}

public typealias UpgradeRequirementBannerControllerProtocol = UpgradeRequirementBannerObserving & UpgradeRequirementHandling

public final class UpgradeRequirementBannerController: UpgradeRequirementBannerObserving, UpgradeRequirementHandling {
    private let localSettings: LocalSettings
    private let appStorePageURL: URL

    public init(appStorePageURL: URL, localSettings: LocalSettings) {
        self.appStorePageURL = appStorePageURL
        self.localSettings = localSettings
    }

    // Only present banner in the default tab
    public func subscribeToUpgradeRequirement(currentTab: TabBarItem?) -> AnyPublisher<UpgradeRequirementLevel, Never> {
        localSettings.publisher(for: \.upgradeRequirementResult)
            .combineLatest(
                localSettings.publisher(for: \.defaultHomeTabTag),
                localSettings.publisher(for: \.hasDismissedUpgradeBanner)
            )
            .removeDuplicates(by: { previous, current in
                previous.0 == current.0 && previous.1 == current.1 && previous.2 == current.2
            })
            .receive(on: DispatchQueue.main)
            .map { result, defaultTab, hasDismissed in
                guard currentTab?.rawValue == defaultTab, let result else { return UpgradeRequirementLevel.none }
                if !result.updateRequired.isEmpty {
                    return UpgradeRequirementLevel.required
                } else if !result.updateRecommended.isEmpty, !hasDismissed {
                    return UpgradeRequirementLevel.recommend
                } else {
                    return UpgradeRequirementLevel.none
                }
            }
            .eraseToAnyPublisher()
    }

    public func closeUpgradeHintBanner() {
        localSettings.hasDismissedUpgradeBanner = true
    }

    public func openAppStore() {
        guard UIApplication.shared.canOpenURL(appStorePageURL) else { return }
        UIApplication.shared.open(appStorePageURL)
    }
}
