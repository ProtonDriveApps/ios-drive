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

class AddressBootstrapStarter: AppBootstrapper {
    let localAddressProvider: SessionVault
    let remoteAddressProvider: AddressProvider
    let connectionStateResource: ConnectionStateResource

    init(
        localAddressProvider: SessionVault,
        remoteAddressProvider: AddressProvider,
        connectionStateResource: ConnectionStateResource
    ) {
        self.localAddressProvider = localAddressProvider
        self.remoteAddressProvider = remoteAddressProvider
        self.connectionStateResource = connectionStateResource
    }

    func bootstrap() async throws {
        if let addresses = localAddressProvider.addresses, !addresses.isEmpty {
            let isSuccess = try validateAddresses(addresses: addresses)
            if !isSuccess {
                try await fetchRemoteAddress()
            }
        } else {
            try await fetchRemoteAddress()
        }
    }

    private func fetchRemoteAddress() async throws {
        guard connectionStateResource.currentState.isReachable else {
            throw NetworkStateError.deviceIsOffline
        }
        guard localAddressProvider.userInfo != nil else {
            throw LoggingOutError("The session is invalid.")
        }
        Log.debug("Fetching remote addresses...", domain: .applicationBootstrap)
        let addresses = try await remoteAddressProvider.fetchAddresses()
        localAddressProvider.storeAddresses(addresses)
    }

    /// - Returns: Validate success
    private func validateAddresses(addresses: [Address]) throws -> Bool {
        guard localAddressProvider.userInfo != nil else {
            throw LoggingOutError("The session is invalid.")
        }

        for address in addresses {
            let pairs = address.activeKeys.compactMap(KeyPair.init)
            if pairs.isEmpty {
                Log.warning("KeyPair initialized failed", domain: .applicationBootstrap)
                return false
            }
        }
        return true
    }
}
