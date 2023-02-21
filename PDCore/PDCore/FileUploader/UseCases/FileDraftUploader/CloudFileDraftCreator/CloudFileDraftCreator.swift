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

protocol CloudFileDraftCreator {
    typealias CloudFileDraftCreatorCompletion = (Result<RemoteUploadedNewFile, Error>) -> Void

    func createNewFileDraft(_ draft: UploadableFileDraft, completion: @escaping CloudFileDraftCreatorCompletion)
}

struct UploadableFileDraft: Equatable {
    let shareID: String
    let parentLinkID: String
    let armoredName: Armored
    let nameHash: String
    let nodeKey: String
    let nodePassphrase: String
    let nodePassphraseSignature: String
    let signatureAddress: String
    let contentKeyPacket: String
    let contentKeyPacketSignature: String
    let mimeType: String
}
