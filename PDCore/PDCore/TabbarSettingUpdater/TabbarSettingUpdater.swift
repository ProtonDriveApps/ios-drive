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

final class TabbarSettingUpdater {
    private let client: PDClient.Client
    private let cloudSlot: CloudSlot
    private let featureFlags: any FeatureFlagsRepository
    private let localSettings: LocalSettings
    private let networking: PMAPIService
    
    init(
        client: PDClient.Client,
        cloudSlot: CloudSlot,
        featureFlags: any FeatureFlagsRepository,
        localSettings: LocalSettings,
        networking: PMAPIService
    ) {
        self.client = client
        self.cloudSlot = cloudSlot
        self.featureFlags = featureFlags
        self.localSettings = localSettings
        self.networking = networking
    }
    
    func updateTabSettingBasedOnUserPlan(share: Share) async {
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
        try await cloudSlot.moc.perform {
            guard let id = share.volume?.id else {
                throw share.invalidState("Photos Share has no volume.")
            }
            return id
        }
    }
    
    private func updateTabSettingForB2BUser(share: Share) async {
//        do {
//            let volumeID = try await getVolumeID(from: share)
//            let response = try await client.getPhotosList(with: .init(volumeId: volumeID, lastId: nil, pageSize: 1))
//            await MainActor.run {
//                localSettings.isB2BUser = true
//                localSettings.isPhotoBackupFeatureDisabled = false
//                localSettings.defaultHomeTabTag = 0
//            }
//        } catch {
//            await MainActor.run {
//                localSettings.isB2BUser = true
//                localSettings.isPhotoBackupFeatureDisabled = false
//                localSettings.defaultHomeTabTag = 0
//            }
//        }
        await MainActor.run {
            localSettings.isB2BUser = true
            localSettings.isPhotoBackupFeatureDisabled = false
            localSettings.defaultHomeTabTag = 0
        }
    }
    
    private func updateTabSettingForNormalUser() async {
        await MainActor.run {
            localSettings.isB2BUser = false
            localSettings.isPhotoBackupFeatureDisabled = false
        }
    }
}
