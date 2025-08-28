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

public struct NodeCryptoMaterial {
    public let isAnonymous: Bool
    public let id: AnyVolumeIdentifier
    public let oldNodeName: String
    public let oldDecryptedNodeName: String
    public let oldNodePassphrase: String
    public let oldDecryptedNodePassphrase: String
    public let oldNodeNameSignatureEmail: String?
    public let oldNodeSignatureEmail: String?
    public let oldNameHash: String
    public let oldParentKey: String
    public let oldParentPassphrase: String
    public let signersKit: SignersKit
    public let contentDigest: FileContentDigest?
}

public typealias NodeParentCryptoMaterial = EncryptingParent
