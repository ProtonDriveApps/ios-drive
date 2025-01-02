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

public protocol EncryptionResource {
    func encryptAndSign(
        _ cleartext: String,
        key: String,
        addressPassphrase: String,
        addressPrivateKey: String
    ) throws -> String
    func generateNodeKeys(
        addressPassphrase: String,
        addressPrivateKey: String,
        parentKey: String
    ) throws -> KeyCredentials
    func generateNodeHashKey(nodeKey: String, passphrase: String) throws -> String
    func generateContentKeys(
        nodeKey: ArmoredKey,
        nodePassphrase: Passphrase
    ) throws -> RevisionContentKeys
    func makeHmac(string: String, hashKey: String) throws -> String
    func sign(
        data: Data,
        addressKey: String,
        addressPassphrase: String
    ) throws -> String
    func encryptSessionKey(sessionKey: SessionKey, with key: String) throws -> KeyPacket
    func sign(
        _ input: KeyPacket,
        context: String,
        privateKey: ArmoredKey,
        passphrase: Passphrase
    ) throws -> Data
    func sign(
        text: String,
        context: String,
        privateKey: ArmoredKey,
        passphrase: Passphrase
    ) throws -> Data
}
