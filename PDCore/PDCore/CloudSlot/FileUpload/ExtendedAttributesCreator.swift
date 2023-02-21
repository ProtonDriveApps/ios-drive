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

protocol ExtendedAttributesCreator {
    typealias EncryptAndSign = (PlainData, ArmoredEncryptionKey, ArmoredSigningKey, Passphrase) throws -> ArmoredMessage

    func make(nodeKey: ArmoredKey, addressKey: ArmoredKey, addressPassphrase: Passphrase) throws -> ArmoredMessage
}

struct CryptoExtendedAttributesCreator: ExtendedAttributesCreator {
    let encryptAndSign: EncryptAndSign
    let url: URL
    let maxBlockSize: Int

    init(
        encryptAndSign: @escaping EncryptAndSign = Encryptor.encryptAndSignWithCompression,
        url: URL,
        maxBlockSize: Int
    ) {
        self.encryptAndSign = encryptAndSign
        self.url = url
        self.maxBlockSize = maxBlockSize
    }

    func make(nodeKey: ArmoredKey, addressKey: ArmoredKey, addressPassphrase: Passphrase) throws -> ArmoredMessage {
        let publicNodeKey = try Encryptor.getPublicKey(fromPrivateKey: nodeKey)

        let totalSize = url.fileSize ?? 0
        let blockSizes = totalSize.split(divisor: maxBlockSize)
        let modificationTime = url.contentModificationDate ?? Date()

        let commonAttributes = ExtendedAttributes.Common(modificationTime: modificationTime, size: totalSize, blockSizes: blockSizes)
        let xAttributes = try ExtendedAttributes(common: commonAttributes).encoded()
        return try encryptAndSign(xAttributes, publicNodeKey, addressKey, addressPassphrase)
    }
}
