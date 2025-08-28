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

public typealias ArmoredKey = String
public typealias ArmoredMessage = String
public typealias ArmoredSignature = String
public typealias SignerEmail = String

public typealias HashKey = String

public typealias VerifiedText = DecryptedMessage<String>
public typealias VerifiedBinary = DecryptedMessage<Data>

public typealias KeyPacket = Data
public typealias DataPacket = Data
public typealias Armored = String
public typealias Passphrase = String

typealias PlainData = Data
typealias PlainText = String
typealias ArmoredEncryptionKey = ArmoredKey
typealias ArmoredSigningKey = ArmoredKey

public typealias SessionKey = Data
public typealias PublicKey = String
