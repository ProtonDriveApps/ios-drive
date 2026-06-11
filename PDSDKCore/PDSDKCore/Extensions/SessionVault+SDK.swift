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
import ProtonCoreDataModel
import PDCore
import ProtonDriveSDK

extension SessionVault: @retroactive AccountClientProtocol, @unchecked Sendable {
    public func getAddress(addressId: String) -> Address? {
        let address = getAddress(withId: addressId)
        if address == nil {
            Log.warning("There is no address for \(addressId)", domain: .sdk)
        }
        return address
    }

    public func getDefaultAddress() -> Address? {
        return currentAddress()
    }

    public func getAddressPrimaryPrivateKey(addressId: String) -> Data? {
        guard let address = getAddress(addressId: addressId) else { return nil }
        guard let primaryKey = address.activeKeys.first(where: { $0.primary == 1 }) else {
            Log.warning("There is no associated primary key for the \(addressId)", domain: .sdk)
            return nil
        }
        do {
            return try unlockedAddressPrivateKeyData(for: primaryKey)
        } catch {
            Log.error("Retrieve private key data failed", error: error, domain: .sdk)
            return nil
        }
    }

    public func getAddressPrivateKeys(addressId: String) -> [Data]? {
        guard let address = getAddress(addressId: addressId) else { return nil }
        do {
            return try address.activeKeys.map { key in
                try unlockedAddressPrivateKeyData(for: key)
            }
        } catch {
            Log.error("Retrieve private key data failed", error: error, domain: .sdk)
            return nil
        }
    }

    public func getAddressPublicKeysRequest(emailAddress: String) -> [Data] {
        return getPublicKeys(for: emailAddress)
            .map { Data($0.utf8) }
    }
}
