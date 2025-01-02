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
import PDClient
import ProtonCoreNetworking
import ProtonCorePayments
import ProtonCoreServices

public protocol TabbarSettingUpdaterProtocol {
    func updateTabSettingBasedOnUserPlan(share: Share) async
}

public final class TabbarSettingUpdater: TabbarSettingUpdaterProtocol {
    private let client: PDClient.Client
    private let featureFlags: any FeatureFlagsRepository
    private let localSettings: LocalSettings
    private let networking: PMAPIService
    private let storageManager: StorageManager

    public init(
        client: PDClient.Client,
        featureFlags: any FeatureFlagsRepository,
        localSettings: LocalSettings,
        networking: PMAPIService,
        storageManager: StorageManager
    ) {
        self.client = client
        self.featureFlags = featureFlags
        self.localSettings = localSettings
        self.networking = networking
        self.storageManager = storageManager
    }
    
    public func updateTabSettingBasedOnUserPlan(share: Share) async {
        guard featureFlags.isEnabled(flag: .driveDisablePhotosForB2B) else {
            await updateTabSettingForNormalUser()
            return
        }
        let req = OrganizationsRequest(api: networking)
        do {
            let resDict = try await networking.perform(request: req).1
            let b2bPlans = ["mailpro2022", "mailbiz2024", "bundlepro2024", "drivebiz2024", "bundlepro2022", "enterprise2022"]
            if let organization = resDict["Organization"] as? JSONDictionary,
               let planName = organization["PlanName"] as? String,
               b2bPlans.contains(planName) {
                await updateTabSettingForB2BUser(share: share)
            } else {
                await updateTabSettingForNormalUser()
            }
            
        } catch {
            await updateTabSettingForNormalUser()
        }
    }
    
    private func getVolumeID(from share: Share) async throws -> String {
        try await storageManager.backgroundContext.perform {
            guard let id = share.volume?.id else {
                throw share.invalidState("Photos Share has no volume.")
            }
            return id
        }
    }
    
    private func updateTabSettingForB2BUser(share: Share) async {
        await MainActor.run {
            localSettings.isB2BUser = true
            // If there is cached data, do not revert the value.
            if localSettings.defaultHomeTabTagValue == nil {
                localSettings.defaultHomeTabTag = 0
            }
        }
    }
    
    private func updateTabSettingForNormalUser() async {
        await MainActor.run {
            localSettings.isB2BUser = false
        }
    }
}
