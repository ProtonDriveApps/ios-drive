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
import ProtonCoreFeatureFlags

final class FeatureFlagsAwarePopulateViewModelDecorator: PopulateViewModelProtocol {
    let connectionResource: ConnectionStateResource
    let localSettings: LocalSettings
    let viewModel: PopulateViewModelProtocol
    let featureFlagsRepository: FeatureFlagsStartingRepository
    let entitlementsManager: EntitlementsManagerProtocol

    init(
        connectionResource: ConnectionStateResource,
        localSettings: LocalSettings,
        viewModel: PopulateViewModelProtocol,
        featureFlagsRepository: FeatureFlagsStartingRepository,
        entitlementsManager: EntitlementsManagerProtocol
    ) {
        self.connectionResource = connectionResource
        self.localSettings = localSettings
        self.viewModel = viewModel
        self.featureFlagsRepository = featureFlagsRepository
        self.entitlementsManager = entitlementsManager
    }

    func populate() async throws {
        try await fetchFeatureFlags()
        try await viewModel.populate()
    }

    private func fetchFeatureFlags() async throws {
        if localSettings.didFetchFeatureFlags == true {
            Task.detached { [weak self] in
                await measure(message: "Bootstrap feature flag in background", domain: .applicationBootstrap) {
                    try? await self?.updateFeatureFlags(hasCached: true)
                }
            }
        } else {
            try await measure(message: "Bootstrap feature flag", domain: .applicationBootstrap) {
                // Call featureFlagsRepository.startAsync() before viewModel.viewDidLoad() the first time
                try await updateFeatureFlags(hasCached: false)
            }
        }
    }

    private func updateFeatureFlags(hasCached: Bool) async throws {
        guard connectionResource.currentState.isReachable else {
            throw NetworkStateError.deviceIsOffline
        }
        try await featureFlagsRepository.startAsync()
        if hasCached == false {
            localSettings.didFetchFeatureFlags = true
        }
    }

    // This was initially for public edit sharing
    // Although public edit sharing no longer requires entitlement
    // It's kept for potential future features that might need entitlement
    private func updateEntitlement() async throws {
        if localSettings.driveDynamicEntitlementConfiguration {
            try await entitlementsManager.updateEntitlementsIfNeeded()
        } else {
            localSettings.driveEntitlementsValue = nil
            localSettings.driveEntitlementsUpdatedTimeValue = nil
        }
    }
}
