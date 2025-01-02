// Copyright (c) 2023 Proton AG
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

// TODO: Rename to SignersKitFactory once the current one is removed from the project

/// We should only sign with the principal key of the current address  when creating a new volume
public protocol SignersKitFactoryProtocol {
    func make(forSigner signer: Signer) throws -> SignersKit
    func make(forAddressID addressID: String) throws -> SignersKit
}

/// Wether to use the current main address, or some specified address
///  - case main: Build a SignersKit object for the current main address email.
///  - case address(String): Build a SignersKit object using the specified email.
public enum Signer {
    case main
    case address(String) // Should be removed
}

extension SessionVault: SignersKitFactoryProtocol {
    public func make(forSigner signer: Signer) throws -> SignersKit {
        let address = try getSignerAddress(signer)

        guard let addressKey = address.activeKeys.first else {
            throw Errors.addressHasNoActiveKeys
        }

        let addressPassphrase = try addressPassphrase(for: addressKey)

        return SignersKit(address: address, addressKey: addressKey, addressPassphrase: addressPassphrase)

    }

    /// Deprecated in iOS: `getSignerAddress( .address())`
    ///  Use with main only in Volume creation
    private func getSignerAddress(_ signer: Signer) throws -> Address {
        switch signer {
        case .main:
            guard let address = currentAddress() else { throw Errors.addressNotFound }
            return address
        case .address(let email):
            guard let address = getAddress(for: email) else { throw Errors.addressNotFound }
            return address
        }
    }

    public func make(forAddressID addressID: String) throws -> SignersKit {
        guard let address = getAddress(withId: addressID) else { throw Errors.addressByIDNotFound }

        // The first key is the current primary
        guard let addressKey = address.activeKeys.first else {
            throw Errors.addressHasNoActiveKeys
        }
        let addressPassphrase = try addressPassphrase(for: addressKey)

        return SignersKit(address: address, addressKey: addressKey, addressPassphrase: addressPassphrase)
    }
}
