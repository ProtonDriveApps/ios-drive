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
import ProtonCoreNetworking
import ProtonCorePayments
import ProtonCoreServices
import PDClient
import PDCore
import PDCoreIOS

public protocol B2BUserStatusStarterProtocol {
    func bootstrap() async throws
}

public final class B2BUserStatusStarter: B2BUserStatusStarterProtocol {
    private let featureFlags: any FeatureFlagsRepository
    private let localSettings: LocalSettings
    private let networking: PMAPIService

    public init(
        featureFlags: any FeatureFlagsRepository,
        localSettings: LocalSettings,
        networking: PMAPIService
    ) {
        self.featureFlags = featureFlags
        self.localSettings = localSettings
        self.networking = networking
    }

    public func bootstrap() async throws {
        let isFirstFetch = !(localSettings.didFetchB2BStatus ?? false)

        if isFirstFetch {
            try await determineAndStoreB2BStatus()
            if localSettings.isB2BUser {
                localSettings.defaultHomeTabTag = TabBarItem.files.tag
            }
            localSettings.didFetchB2BStatus = true
        } else {
            Task {
                do {
                    try await determineAndStoreB2BStatus()
                } catch {
                    Log.error("Fetching B2B status failed", error: error, domain: .application)
                }
            }
        }
    }

    private func determineAndStoreB2BStatus() async throws {
        guard featureFlags.isEnabled(flag: .driveDisablePhotosForB2B) else {
            localSettings.isB2BUser = false
            return
        }

        let request = OrganizationsRequest(api: networking)
        do {
            let (_, responseDict) = try await networking.perform(request: request)
            let b2bPlans = ["mailpro2022", "mailbiz2024", "bundlepro2024", "drivebiz2024", "bundlepro2022", "enterprise2022"]

            if let org = responseDict["Organization"] as? JSONDictionary,
               let planName = org["PlanName"] as? String,
               b2bPlans.contains(planName) {
                localSettings.isB2BUser = true
            } else {
                localSettings.isB2BUser = false
            }
        } catch let remoteError as ResponseError where remoteError.code == 2501 {
            localSettings.isB2BUser = false
        } catch {
            localSettings.isB2BUser = false
            throw error
        }
    }
}
