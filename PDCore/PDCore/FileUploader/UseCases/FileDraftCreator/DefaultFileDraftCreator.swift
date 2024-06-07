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

struct FileDraftUploadableDraft: Equatable {
    let uploadID: UUID
    let hash: String
    let clearName: String
    let armoredName: Armored
    let nameSignatureAddress: String
    let nodeKey: String
    let nodePassphrase: String
    let nodePassphraseSignature: String
    let contentKeyPacket: String
    let contentKeyPacketSignature: String
    let parent: NodeIdentifier
    let parentNodeHashKey: String
    let mimeType: String
    let clientUID: String
    let file: File
}

class DefaultFileDraftCreator: FileDraftCreator {
    let cloudFileCreator: CloudFileDraftCreator
    let signersKitFactory: SignersKitFactoryProtocol

    private(set) var isCancelled = false

    init(
        cloudFileCreator: CloudFileDraftCreator,
        signersKitFactory: SignersKitFactoryProtocol
    ) {
        self.cloudFileCreator = cloudFileCreator
        self.signersKitFactory = signersKitFactory
    }

    func create(_ draft: FileDraft, completion: @escaping Completion) {
        guard !isCancelled else { return }

        do {
            let nameResolvingDraft = try draft.getNameResolvingFileDraft()
            uploadDraft(nameResolvingDraft, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    func uploadDraft(_ draft: FileDraftUploadableDraft, completion: @escaping Completion) {
        guard !isCancelled else { return }
        
        let uploadableFileDraft = UploadableFileDraft(
            shareID: draft.parent.shareID,
            parentLinkID: draft.parent.nodeID,
            armoredName: draft.armoredName,
            nameHash: draft.hash,
            nodeKey: draft.nodeKey,
            nodePassphrase: draft.nodePassphrase,
            nodePassphraseSignature: draft.nodePassphraseSignature,
            signatureAddress: draft.nameSignatureAddress,
            contentKeyPacket: draft.contentKeyPacket,
            contentKeyPacketSignature: draft.contentKeyPacketSignature,
            mimeType: draft.mimeType,
            clientUID: draft.clientUID
        )

         cloudFileCreator.createNewFileDraft(uploadableFileDraft) { [weak self] result in
             guard let self = self, !self.isCancelled else { return }

             switch result {
             case .success(let uploadedFileDraft):
                 do {
                     let nameHash = uploadableFileDraft.nameHash
                     let armoredName = uploadableFileDraft.armoredName
                     try self.finalize(draft.file, uploaded: uploadedFileDraft, nameHash: nameHash, armoredName: armoredName)
                     Log.info("STAGE: 2.1 Create File ✍️☁️🐣 finished ✅. UUID: \(draft.uploadID), FileID: \(uploadedFileDraft.fileID), RevisionID: \(uploadedFileDraft.revisionID)", domain: .uploader)
                     completion(.success(draft.file))

                 } catch {
                     completion(.failure(error))
                 }

             case .failure(let error):
                 completion(.failure(error))
             }
         }
     }

     func cancel() {
         isCancelled = true
     }

     func finalize(_ file: File, uploaded: RemoteUploadedNewFile, nameHash: String, armoredName: Armored) throws {
         guard let moc = file.moc else { throw File.noMOC() }

         try moc.performAndWait { [weak self] in
             guard let self, !self.isCancelled else { return }
             
             file.id = uploaded.fileID
             file.activeRevisionDraft?.id = uploaded.revisionID

             file.name = armoredName
             file.nodeHash = nameHash

             file.clearName = nil

             try moc.saveOrRollback()
         }
     }
    
}
