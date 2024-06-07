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
            mimeType: draft.mimeType,
            clientUID: draft.clientUID
        )

        client.postFile(
            draft.shareID,
            parameters: parameters,
            completion: { [weak self] result in
                self?.queue.async {
                    completion(result.map { RemoteUploadedNewFile(fileID: $0.ID, revisionID: $0.revisionID) })
                }
            }
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
        let parameters = NewPhotoBlocksParameters(
            addressID: revision.addressID,
            shareID: revision.shareID,
            linkID: revision.nodeID,
            revisionID: revision.revisionID,
            blockList: revision.blocks.map { .init(size: $0.size, index: $0.index, encSignature: $0.encryptedSignature, hash: $0.hash, verificationToken: $0.verificationToken) },
            thumbnailList: revision.thumbnails.map { .init(size: $0.size, type: $0.type, hash: $0.hash) }
        )

        client.postBlocks(
            parameters: parameters,
            completion: { [weak self] response in
                self?.queue.async {
                    onCompletion(response.map { revision.makeFull(blockLinks: $0.blocks, thumbnailLinks: $0.thumbnails) })
                }
            }
        )
    }
}

// MARK: - CloudRevisionCommitter
protocol CloudRevisionCommitter {
    func commit(_ revision: CommitableRevision, completion: @escaping (Result<Void, Error>) -> Void)
}

extension CloudSlot: CloudRevisionCommitter {
    func commit(_ revision: CommitableRevision, completion: @escaping (Result<Void, Error>) -> Void) {
        // Client platform and version
        var photoParameter: UpdateRevisionParameters.Photo?
        if let photo = revision.photo {
            photoParameter = UpdateRevisionParameters.Photo(captureTime: photo.captureTime, mainPhotoLinkID: photo.mainPhotoLinkID, exif: nil, contentHash: photo.contentHash) // We don't upload exif until the format is aligned.
        }
        let parameters = UpdateRevisionParameters(
            manifestSignature: revision.manifestSignature,
            signatureAddress: revision.signatureAddress,
            extendedAttributes: revision.xAttributes,
            photo: photoParameter
        )

        client.putRevision(
            shareID: revision.shareID,
            fileID: revision.fileID,
            revisionID: revision.revisionID,
            parameters: parameters,
            completion: { [weak self] result in
                self?.queue.async {
                    completion(result)
                }
            }
        )
    }
}

// MARK: - CloudRevisionCommiter
enum UploadedRevisionCheckerError: LocalizedError {
    case revisionNotCommitedFakeNews
    case noXAttrsInActiveRevision
    case xAttrsDoNotMatch
    case blockUploadEmpty
    case blockUploadSizeIncorrect
    case blockUploadCountIncorrect

    var errorDescription: String? {
        switch self {
        case .revisionNotCommitedFakeNews:
            return "Revision not finalized"
        case .noXAttrsInActiveRevision:
            return "Missing XAttrs in active revision"
        case .xAttrsDoNotMatch:
            return "XAttrs don't match those uploaded"
        case .blockUploadEmpty:
            return "Some file parts were empty"
        case .blockUploadSizeIncorrect:
            return "Some file parts did not match their expected sizes"
        case .blockUploadCountIncorrect:
            return "Some file parts failed to upload"
        }
    }
}

protocol UploadedRevisionChecker {
    typealias XAttrs = String
    func checkUploadedRevision(_ id: RevisionIdentifier, completion: @escaping (Result<XAttrs, Error>) -> Void)
}

extension CloudSlot: UploadedRevisionChecker {
    func checkUploadedRevision(_ id: RevisionIdentifier, completion: @escaping (Result<XAttrs, Error>) -> Void) {
        client.getRevision(id.share, fileID: id.file, revisionID: id.revision) { result in
            switch result {
            case .success(let revision) where revision.state == .active:
                if let unwrappedXAttr = revision.XAttr {
                    completion(.success(unwrappedXAttr))
                } else {
                    completion(.failure(UploadedRevisionCheckerError.noXAttrsInActiveRevision))
                }
            case .success:
                completion(.failure(UploadedRevisionCheckerError.revisionNotCommitedFakeNews))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - CloudRevisionCreator
protocol CloudRevisionCreator {
    func createRevision(for file: NodeIdentifier, onCompletion: @escaping (Result<RevisionIdentifier, Error>) -> Void)
}

extension CloudSlot: CloudRevisionCreator {
    func createRevision(for file: NodeIdentifier, onCompletion: @escaping (Result<RevisionIdentifier, Error>) -> Void) {
        client.postRevision(file.nodeID, shareID: file.shareID) { [weak self] result in
            self?.queue.async {
                onCompletion(result.map { RevisionIdentifier(share: file.shareID, file: file.nodeID, revision: $0.ID) })
            }
        }
    }
}
