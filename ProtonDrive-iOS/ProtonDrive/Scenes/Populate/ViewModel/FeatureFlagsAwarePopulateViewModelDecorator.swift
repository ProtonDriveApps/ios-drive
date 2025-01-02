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

final class FeatureFlagsAwarePopulateViewModelDecorator: PopulateViewModelProtocol {
    let localSettings: LocalSettings
    let viewModel: PopulateViewModelProtocol
    let featureFlagsRepository: FeatureFlagsStartingRepository
    let entitlementsManager: EntitlementsManagerProtocol

    init(
        localSettings: LocalSettings,
        viewModel: PopulateViewModelProtocol,
        featureFlagsRepository: FeatureFlagsStartingRepository,
        entitlementsManager: EntitlementsManagerProtocol
    ) {
        self.localSettings = localSettings
        self.viewModel = viewModel
        self.featureFlagsRepository = featureFlagsRepository
        self.entitlementsManager = entitlementsManager
    }

    func populate() async throws {
        if localSettings.didFetchFeatureFlags == true {
            // Start loading feature flags in the background
            async let _ = await updateCachedFeatureFlagsAndEntitlement()

            // Call viewModel.viewDidLoad() as soon as possible
            try await viewModel.populate()
        } else {
            // Call featureFlagsRepository.startAsync() before viewModel.viewDidLoad() the first time
            try await featureFlagsRepository.startAsync()
            localSettings.didFetchFeatureFlags = true
            try await updateEntitlement()
            try await viewModel.populate()
        }
    }
    
    private func updateCachedFeatureFlagsAndEntitlement() async {
        do {
            try await featureFlagsRepository.startAsync()
            try await updateEntitlement()
        } catch {
            localSettings.driveEntitlementsValue = nil
            localSettings.driveEntitlementsUpdatedTimeValue = nil
        }
    }
    
    private func updateEntitlement() async throws {
        if localSettings.driveDynamicEntitlementConfiguration {
            try await entitlementsManager.updateEntitlementsIfNeeded()
        } else {
            localSettings.driveEntitlementsValue = nil
            localSettings.driveEntitlementsUpdatedTimeValue = nil
        }
    }
}
