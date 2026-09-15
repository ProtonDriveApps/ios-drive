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
import PDCore

struct NameEncryptor {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func encrypt(parameters: Parameters) throws -> Result {
        let clearName = try clearName(from: parameters.name)
        let encryptedName = try dependencies.encryptor.encryptAndSign(
            clearName,
            key: parameters.nodeKey,
            addressPassphrase: dependencies.signersKit.addressPassphrase,
            addressPrivateKey: dependencies.signersKit.addressKey.privateKey
        )
        let nameHash = try dependencies.encryptor.makeHmac(
            string: clearName,
            hashKey: parameters.decryptedHashKey
        )
        return .init(
            encryptedName: encryptedName,
            nameHash: nameHash,
            signatureEmail: dependencies.signersKit.address.email
        )
    }

    private func clearName(from name: String) throws -> String {
        let clearName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clearName.isEmpty {
            throw Error.emptyClearName
        }
        return clearName
    }
}

extension NameEncryptor {
    struct Dependencies {
        let encryptor: EncryptionResource
        let signersKit: SignersKit
    }

    struct Parameters {
        let name: String
        /// Parent node key
        let nodeKey: String
        /// Parent decrypted hash key
        let decryptedHashKey: Data
    }

    struct Result {
        let encryptedName: String
        let nameHash: String
        let signatureEmail: String
    }

    enum Error: LocalizedError {
        case emptyClearName
    }
}
