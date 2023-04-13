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
    func create(from revision: UploadableRevision, onCompletion: @escaping CloudContentCreator.Completion)
}

extension CloudSlot: CloudContentCreator {
    func create(from revision: UploadableRevision, onCompletion: @escaping CloudContentCreator.Completion) {
        let parameters = NewBlocksParameters(
            blockList: revision.blocks.map(NewBlockMeta.init),
            thumbnail: NewThumbnailMeta(thumbnail: revision.thumbnail),
            addressID: revision.addressID,
            shareID: revision.shareID,
            linkID: revision.nodeID,
            revisionID: revision.revisionID
        )

        client.postBlocks(
            parameters: parameters,
            completion: { onCompletion($0.map { revision.makeFull(blockLinks: $0, thumbnailLink: $1) }) }
        )
    }
}

// MARK: - CloudRevisionCommiter
protocol CloudRevisionCommiter {
    func commit(_ revision: CommitableRevision, completion: @escaping (Result<Void, Error>) -> Void)
}

extension CloudSlot: CloudRevisionCommiter {
    func commit(_ revision: CommitableRevision, completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters = UpdateRevisionParameters(
            state: .active,
            blockList: revision.blockList.map { UpdateRevisionBlocks(index: $0.index, token: $0.token) },
            manifestSignature: revision.manifestSignature,
            signatureAddress: revision.signatureAddress,
            extendedAttributes: revision.xAttributes
        )

        client.putRevision(
            shareID: revision.shareID,
            fileID: revision.fileID,
            revisionID: revision.revisionID,
            parameters: parameters,
            completion: completion
        )
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
