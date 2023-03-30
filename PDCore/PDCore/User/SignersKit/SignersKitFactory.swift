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
public protocol SignersKitFactoryProtocol {
    func make(forSigner signer: Signer) throws -> SignersKit
}

/// Wether to use the current main address, or some specified address
///  - case main: Build a SignersKit object for the current main address email.
///  - case address(String): Build a SignersKit object using the specified email.
public enum Signer {
    case main
    case address(String)
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
}

@available(*, deprecated, message: "Use directly SessionVault through SignersKitFactoryProtocol")
public final class SignersKitFactory {
    private let sessionVault: SessionVault

    init(sessionVault: SessionVault) {
        self.sessionVault = sessionVault
    }

    func make(signatureAddress: String) throws -> SignersKit {
        try SignersKit(signatureAddress: signatureAddress, sessionVault: sessionVault)
    }

    /// Use it only at the beginning
    func make() throws -> SignersKit {
        try SignersKit(sessionVault: sessionVault)
    }
}
