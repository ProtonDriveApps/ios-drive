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

public typealias Address = AddressManager.Address
public typealias AddressKey = AddressManager.AddressKey

public struct SignersKit {
    
    enum Errors: Error {
        case addressHasNoKeys
        case noAddressWithRequestedSignature
        case noAddressFound
    }
    
    public let address: Address
    public let addressKey: AddressKey
    public let addressPassphrase: String

    public init(address: Address, addressKey: AddressKey, addressPassphrase: String) {
        self.address = address
        self.addressKey = addressKey
        self.addressPassphrase = addressPassphrase
    }

    @available(*, deprecated, message: "Build directly from SessionVault")
    init(address: Address, sessionVault: SessionVault) throws {
        self.address = address
        guard let addressKey = address.keys.first else {
            throw Errors.addressHasNoKeys
        }
        self.addressKey = addressKey
        self.addressPassphrase = try sessionVault.addressPassphrase(for: addressKey)
    }

    @available(*, deprecated, message: "Build directly from SessionVault")
    init(signatureAddress: String, sessionVault: SessionVault) throws {
        guard let address = sessionVault.getAddress(for: signatureAddress) else {
            throw Errors.noAddressWithRequestedSignature
        }
        try self.init(address: address, sessionVault: sessionVault)
    }

    @available(*, deprecated, message: "Use directly SessionVault through SignersKitFactoryProtocol")
    public init(sessionVault: SessionVault) throws {
        guard let address = sessionVault.currentAddress() else {
            throw Errors.noAddressFound
        }
        try self.init(address: address, sessionVault: sessionVault)
    }
}
