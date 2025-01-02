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

public struct DocumentIdentifier: Codable {
    public let volumeID: String
    public let linkID: String
    public let revisionID: String
}

public struct NewDocumentPayload: Codable, Equatable {
    let name: String
    let hash: String
    let parentLinkID: String
    let nodeKey: String
    let nodePassphrase: String
    let nodePassphraseSignature: String
    let signatureAddress: String
    let contentKeyPacket: String
    let contentKeyPacketSignature: String
    let manifestSignature: String

    public init(
        name: String,
        hash: String,
        parentLinkID: String,
        nodeKey: String,
        nodePassphrase: String,
        nodePassphraseSignature: String,
        signatureAddress: String,
        contentKeyPacket: String,
        contentKeyPacketSignature: String,
        manifestSignature: String
    ) {
        self.name = name
        self.hash = hash
        self.parentLinkID = parentLinkID
        self.nodeKey = nodeKey
        self.nodePassphrase = nodePassphrase
        self.nodePassphraseSignature = nodePassphraseSignature
        self.signatureAddress = signatureAddress
        self.contentKeyPacket = contentKeyPacket
        self.contentKeyPacketSignature = contentKeyPacketSignature
        self.manifestSignature = manifestSignature
    }
}

public struct NewDocumentParameters {
    let shareId: String
    let payload: NewDocumentPayload

    public init(shareId: String, payload: NewDocumentPayload) {
        self.shareId = shareId
        self.payload = payload
    }
}

public protocol NewDocumentRepository {
    func create(with parameters: NewDocumentParameters) async throws -> DocumentIdentifier
}
