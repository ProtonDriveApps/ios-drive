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

import ProtonCorePaymentsV2
import PDCore
import PDCoreIOS
import PDClient
import ProtonCoreServices

final class PaymentsBootstrapper: AppBootstrapper {
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let connectionStateResource: ConnectionStateResource
    private let coreAPIService: ProtonCoreServices.APIService

    init(
        featureFlagsController: FeatureFlagsControllerProtocol,
        connectionStateResource: ConnectionStateResource,
        coreAPIService: ProtonCoreServices.APIService
    ) {
        self.featureFlagsController = featureFlagsController
        self.connectionStateResource = connectionStateResource
        self.coreAPIService = coreAPIService
    }

    func bootstrap() async throws {
        await measure(message: "Check payment", domain: .applicationBootstrap) {
            guard featureFlagsController.hasPaymentsV2 else { return }

            do {
                guard connectionStateResource.currentState.isReachable else {
                    throw NetworkStateError.deviceIsOffline
                }
                let manager = RemoteManager(apiService: coreAPIService)
                let configuration = TransactionsObserverConfiguration(remoteManager: manager)
                TransactionsObserver.shared.setConfiguration(configuration)
                try await TransactionsObserver.shared.start()
            } catch {
                Log.error("Failed to start observing transactions", error: error, domain: .subscriptions)
            }
        }
    }
}
