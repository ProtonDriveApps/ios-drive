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

extension CloudSlot: CloudFileDraftCreator {

    func createNewFileDraft(_ draft: UploadableFileDraft, completion: @escaping CloudFileDraftCreatorCompletion) {
        do {
            let signersKit = try signersKitFactory.make(signatureAddress: draft.signatureAddress)

            client.postFile(
                draft.shareID,
                parameters: .init(
                    name: draft.armoredName,
                    hash: draft.nameHash,
                    parentLinkID: draft.parentLinkID,
                    nodeKey: draft.nodeKey,
                    nodePassphrase: draft.nodePassphrase,
                    nodePassphraseSignature: draft.nodePassphraseSignature,
                    signatureAddress: draft.signatureAddress,
                    contentKeyPacket: draft.contentKeyPacket,
                    contentKeyPacketSignature: draft.contentKeyPacketSignature,
                    mimeType: draft.mimeType
                )
            ) { result in

                    switch result {
                    case .success(let newFile):
                        let uploadedDraft = RemoteUploadedNewFile(
                            fileID: newFile.ID,
                            revisionID: newFile.revisionID,
                            armoredName: draft.armoredName,
                            nameHash: draft.nameHash,
                            nodeKey: draft.nodeKey,
                            addressPrivateKey: signersKit.addressKey.privateKey,
                            addressPassphrase: signersKit.addressPassphrase
                        )
                        completion(.success(uploadedDraft))

                    case .failure(let error):
                        completion(.failure(error))
                    }

            }
        } catch {
            completion(.failure(error))
        }
    }
}
