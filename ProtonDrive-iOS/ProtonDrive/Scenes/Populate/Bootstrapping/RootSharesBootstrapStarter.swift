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

import PDCore
import PDCoreIOS
import PDClient

final class RootSharesBootstrapStarter: AppBootstrapper {
    private let localStore: AppBootstrapper
    private let remote: AppBootstrapper
    private let creating: AppBootstrapper
    private let connectionStateResource: ConnectionStateResource

    init(
        localStore: AppBootstrapper,
        remote: AppBootstrapper,
        creating: AppBootstrapper,
        connectionStateResource: ConnectionStateResource
    ) {
        self.localStore = localStore
        self.connectionStateResource = connectionStateResource
        self.remote = remote
        self.creating = creating
    }

    func bootstrap() async throws {
        try await measure(message: "Bootstrap RootShares", domain: .applicationBootstrap) {
            guard connectionStateResource.currentState.isReachable else {
                Log.debug("Skip fetching the remote shares because the device is offline", domain: .applicationBootstrap)
                try await localStore.bootstrap()
                return
            }
            do {
                try await remote.bootstrap()
            } catch let error as NukingCacheError {
                throw error
            } catch let error as CredentialProviderError {
                throw error
            } catch {
                try await creating.bootstrap()
            }
            try await localStore.bootstrap()
        }
    }
}
