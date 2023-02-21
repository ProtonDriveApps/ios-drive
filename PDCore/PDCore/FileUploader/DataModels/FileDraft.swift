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
public class FileDraft: Equatable {

    let url: URL
    var state: State
    let numberOfBlocks: Int
    let parent: Parent
    let parameters: Parameters
    var nameParameters: NameParameters

    public let uploadID: UUID
    public let file: File

    public init(uploadID: UUID, url: URL, file: File, state: FileDraft.State, numberOfBlocks: Int, parent: FileDraft.Parent, parameters: FileDraft.Parameters, nameParameters: FileDraft.NameParameters) {
        self.uploadID = uploadID
        self.url = url
        self.file = file
        self.state = state
        self.numberOfBlocks = numberOfBlocks
        self.parent = parent
        self.parameters = parameters
        self.nameParameters = nameParameters
    }

    var originalName: String {
        url.lastPathComponent
    }

    var mimeType: String {
        url.mimeType()
    }

    var isEmpty: Bool {
        numberOfBlocks == .zero
    }

    public enum State: Equatable {
        case uploadingDraft
        case encryptingRevision
        case uploadingRevision
        case updateRevision
        case sealingRevision
        case finished
    }

    public struct Parent: Equatable {
        let identifier: NodeIdentifier
        let nodeHashKey: String
    }

    public struct Parameters: Equatable {
        let nodeKey: String
        let nodePassphrase: String
        let nodePassphraseSignature: String
        let contentKeyPacket: String
        let contentKeyPacketSignature: String
        let signatureAddress: String
    }

    public struct NameParameters: Equatable {
        let hash: String
        let clearName: String
        let armoredName: Armored
        let nameSignatureAddress: String
    }

    public static func == (lhs: FileDraft, rhs: FileDraft) -> Bool {
        lhs === rhs
    }
}
