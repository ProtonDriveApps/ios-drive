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

import PDClient
import Foundation

// MARK: - CloudFileDraftCreator
protocol CloudFileDraftCreator {
    typealias CloudFileDraftCreatorCompletion = (Result<RemoteUploadedNewFile, Error>) -> Void
    func createNewFileDraft(_ draft: UploadableFileDraft, completion: @escaping CloudFileDraftCreatorCompletion)
}

extension CloudSlot: CloudFileDraftCreator {
    func createNewFileDraft(_ draft: UploadableFileDraft, completion: @escaping CloudFileDraftCreatorCompletion) {
        let parameters = NewFileParameters(
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

        client.postFile(
            draft.shareID,
            parameters: parameters,
            completion: { completion($0.map { RemoteUploadedNewFile(fileID: $0.ID, revisionID: $0.revisionID) }) }
        )
    }
}

// MARK: - AvailableHashChecker
protocol AvailableHashChecker {
    typealias Completion = (Result<[String], Error>) -> Void
    func checkAvailableHashes(among nameHashPairs: [NameHashPair], onFolder folder: NodeIdentifier, completion: @escaping AvailableHashChecker.Completion)
}

extension CloudSlot: AvailableHashChecker {
    func checkAvailableHashes(among nameHashPairs: [NameHashPair], onFolder folder: NodeIdentifier, completion: @escaping AvailableHashChecker.Completion) {
        let parameters = AvailableHashesParameters(hashes: nameHashPairs.map(\.hash))
        client.postAvailableHashes(shareID: folder.shareID, folderID: folder.nodeID, parameters: parameters, completion: completion)
    }
}

// MARK: - CloudContentCreator
protocol CloudContentCreator {
    typealias Completion = (Result<FullUploadableRevision, Error>) -> Void
    func create(from revision: UploadableRevision, addressID: String, onCompletion: @escaping CloudContentCreator.Completion)
}

extension CloudSlot: CloudContentCreator {
    func create(from revision: UploadableRevision, addressID: String, onCompletion: @escaping CloudContentCreator.Completion) {
        let parameters = NewBlocksParameters(
            blockList: revision.blocks.map(NewBlockMeta.init),
            thumbnail: NewThumbnailMeta(thumbnail: revision.thumbnail),
            addressID: addressID,
            shareID: revision.identifier.share,
            linkID: revision.identifier.file,
            revisionID: revision.identifier.revision
        )

        client.postBlocks(
            parameters: parameters,
            completion: { onCompletion($0.map { revision.makeFull(blockLinks: $0, thumbnailLink: $1) }) }
        )
    }
}

// MARK: - RevisionSealer
extension CloudSlot: RevisionSealer {
    enum CloudRevisionSealerError: Error {
        case revisionNotFound
    }
    
    func makeData(revision: Revision) throws -> RevisionSealData {
        return try moc.performAndWait {
            let revision = revision.in(moc: self.moc)
            // TODO: Use revision signature email instead
            guard let email = revision.signatureAddress else {
                throw revision.invalidState("No signature email in revision.")
            }
            let signersKit = try signersKitFactory.make(forSigner: .address(email))
            let addressKey = signersKit.addressKey.privateKey
            let addressPassphrase = signersKit.addressPassphrase
            let signatureAddress = signersKit.address.email
            
            let sortedBlocks = revision.uploadedBlocks()
            var contentHashes = sortedBlocks.compactMap { $0.sha256 }
            
            if revision.thumbnail?.isUploaded == true,
               let thumbnailsha256 = revision.thumbnail?.uploadable?.sha256 {
                contentHashes.insert(thumbnailsha256, at: 0)
            }
            
            let manifestSignature = try Encryptor.sign(list: Data(contentHashes.joined()),
                                                       addressKey: addressKey,
                                                       addressPassphrase: addressPassphrase)
            
            let blockList = sortedBlocks.map { UpdateRevisionBlocks(index: Int($0.index), token: $0.uploadToken!) }
            return RevisionSealData(
                shareID: revision.file.shareID,
                fileID: revision.file.id,
                revisionID: revision.id,
                blockList: blockList,
                manifestSignature: manifestSignature,
                signatureAddress: signatureAddress,
                xAttributes: revision.xAttributes
            )
        }
    }
    
    func sealRemote(data: RevisionSealData, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters = UpdateRevisionParameters(
            state: .active,
            blockList: data.blockList,
            manifestSignature: data.manifestSignature,
            signatureAddress: data.signatureAddress,
            extendedAttributes: data.xAttributes
        )
        client.putRevision(shareID: data.shareID, fileID: data.fileID, revisionID: data.revisionID, parameters: parameters, completion: completion)
    }
    
    func sealLocal(data: RevisionSealData, revisionURI: URL) throws {
        try moc.performAndWait {
            guard let revision: Revision = self.moc.existingObject(with: revisionURI) else {
                throw CloudRevisionSealerError.revisionNotFound
            }
            revision.created = Date()
            revision.manifestSignature = data.manifestSignature
            revision.state = .active
            
            let file = revision.file
            file.activeRevision = revision
            file.addToRevisions(revision)
            file.size = revision.size
            file.state = .active
            
            file.uploadID = nil
            file.activeRevisionDraft = nil
            file.clientUID = nil
            
            do {
                try self.moc.save()
            } catch {
                self.moc.rollback()
                throw error
            }
        }
    }
}

// MARK: - CloudRevisionCreator
protocol CloudRevisionCreator {
    func createRevision(for file: File, onCompletion: @escaping (Result<RevisionIdentifier, Error>) -> Void)
}

extension CloudSlot: CloudRevisionCreator {

    func createRevision(for file: File, onCompletion: @escaping (Result<RevisionIdentifier, Error>) -> Void) {
        guard let moc = file.moc else {
            onCompletion(.failure(File.noMOC()))
            return
        }

        let identifier = moc.performAndWait { file.identifier }

        client.postRevision(identifier.nodeID, shareID: identifier.shareID) { result in
            onCompletion(result.map { RevisionIdentifier(share: identifier.shareID, file: identifier.nodeID, revision: $0.ID) })
        }
    }

}
