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

import ProtonDriveSDK
import PDSDKCore
import PDCore
import PDClient

public struct SDKOperationPerformerFactory {
    public init() {}

    public func makeFilePerformer(tower: Tower) async throws -> FileOperationPerformer {
        do {
            let featureFlags = tower.featureFlags
            let observabilityReporter = makeReporter(sessionVault: tower.sessionVault)
            let sdkOperationPerformer = try await FileOperationPerformer(
                protonDriveClientConfiguration: makeConfiguration(tower: tower),
                storage: tower.storage,
                networking: tower.networking,
                accountClient: tower.sessionVault,
                rateLimitGate: tower.rateLimitGate,
                urlCacheCleaner: URLCacheCleaner(session: tower.networking),
                fileVerifier: FileVerifier(observabilityReporter: observabilityReporter),
                observabilityReporter: observabilityReporter,
                featureFlagProviderCallback: defaultFeatureFlagProviderCallback(featureFlags: tower.featureFlags)
            )
            Log.info("Initialized SDK operation performer", domain: .sdk)
            return sdkOperationPerformer
        } catch {
            Log.error("Initialize SDK file operation performer failed", error: error, domain: .sdk)
            throw error
        }
    }

    public func makePhotoPerformer(tower: Tower) async throws -> PhotosOperationPerformer {
        do {
            let featureFlags = tower.featureFlags
            let observabilityReporter = makeReporter(sessionVault: tower.sessionVault)
            let photosPerformer = try await PhotosOperationPerformer(
                protonDriveClientConfiguration: makeConfiguration(tower: tower),
                storage: tower.storage,
                networking: tower.networking,
                accountClient: tower.sessionVault,
                rateLimitGate: tower.rateLimitGate,
                urlCacheCleaner: URLCacheCleaner(session: tower.networking),
                fileVerifier: FileVerifier(observabilityReporter: observabilityReporter),
                observabilityReporter: observabilityReporter,
                featureFlagProviderCallback: defaultFeatureFlagProviderCallback(featureFlags: tower.featureFlags)
            )
            return photosPerformer
        } catch {
            Log.error("Initialize SDK photos operation performer failed", error: error, domain: .sdk)
            throw error
        }
    }
}

extension SDKOperationPerformerFactory {
    private func makeReporter(sessionVault: SessionVault) -> ObservabilityReporter {
        let userInfoController = UserInfoControllerFactory().makeController(sessionVault: sessionVault)
        return ObservabilityReporter(dependencies: .init(userInfoController: userInfoController))
    }

    private func makeConfiguration(tower: Tower) -> ProtonDriveClientConfiguration {
        ProtonDriveClientConfiguration(
            baseURL: tower.clientConfiguration.driveApiBase,
            clientUID: tower.sessionVault.getUploadClientUID(),
            downloadOperationalResilience: BasicOperationalResilience.default,
            uploadOperationalResilience: BasicOperationalResilience.default
        )
    }
}
