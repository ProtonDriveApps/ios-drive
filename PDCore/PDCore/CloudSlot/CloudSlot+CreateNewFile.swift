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

// MARK: - AvailableHashChecker
protocol AvailableHashChecker {
    func checkAvailableHashes(among nameHashPairs: [NameHashPair], onFolder folder: NodeIdentifier, completion: @escaping (Result<[String], Error>) -> Void)
}

extension CloudSlot: AvailableHashChecker {

    func checkAvailableHashes(among nameHashPairs: [NameHashPair], onFolder folder: NodeIdentifier, completion: @escaping (Result<[String], Error>) -> Void) {
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
        do {
            let addressID = try signersKitFactory.make(signatureAddress: revision.signatureEmail).address.addressID
            let parameters = NewBlocksParameters(revision: revision, addressID: addressID)

            client.postBlocks(parameters: parameters) { result in
                switch result {
                case .success((let blocks, let thumbnail)):
                    onCompletion(.success(revision.makeFull(blockLinks: blocks, thumbnailLink: thumbnail)))

                case .failure(let error):
                    onCompletion(.failure(error))
                }
            }
        } catch {
            onCompletion(.failure(error))
        }
    }
}

import CoreData

extension NewBlocksParameters {

    init(revision: UploadableRevision, addressID: String) {
        self.init(
            blockList: revision.blocks.map(NewBlockMeta.init),
            thumbnail: NewThumbnailMeta(thumbnail: revision.thumbnail),
            addressID: addressID,
            shareID: revision.identifier.share,
            linkID: revision.identifier.file,
            revisionID: revision.identifier.revision
        )
    }

    static func make(from uploadableRevision: UploadableRevision2, addressID: String, in moc: NSManagedObjectContext) throws -> NewBlocksParameters {
        return try moc.performAndWait {
            let revision = uploadableRevision.revision.in(moc: moc)
            let blocks = uploadableRevision.blocks.map { $0.in(moc: moc) }

            let newBlocksMeta = try blocks.map(NewBlockMeta.init)
            let thumbnailMeta = NewThumbnailMeta(thumbnail: uploadableRevision.thumbnail?.uploadable)

            let parameters = NewBlocksParameters(
                blockList: newBlocksMeta,
                thumbnail: thumbnailMeta,
                addressID: addressID,
                shareID: revision.file.shareID,
                linkID: revision.file.id,
                revisionID: revision.id
            )

            return parameters
        }
    }
}

// MARK: - CloudRevisionSealer
protocol CloudRevisionSealer {
    func seal(revision: Revision, completion: @escaping (Result<Revision, Error>) -> Void)
}

extension CloudSlot: CloudRevisionSealer {
    func seal(revision: Revision, completion: @escaping (Result<Revision, Error>) -> Void)
    {
        self.moc.performAndWait {
            do {
                let revision = revision.in(moc: self.moc)
                let signersKit = try signersKitFactory.make(signatureAddress: revision.file.signatureEmail)
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

                let parameters = UpdateRevisionParameters(
                    state: .active,
                    blockList: blockList,
                    manifestSignature: manifestSignature,
                    signatureAddress: signatureAddress,
                    extendedAttributes: revision.xAttributes
                )

                self.client.putRevision(shareID: revision.file.shareID, fileID: revision.file.id, revisionID: revision.id, parameters: parameters) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .success:
                        self.moc.performAndWait {
                            revision.created = Date()
                            revision.manifestSignature = manifestSignature
                            revision.state = .active

                            let file = revision.file
                            file.activeRevision = revision
                            file.addToRevisions(revision)
                            file.size = revision.size
                            file.state = .active

                            file.uploadIDURL = nil
                            file.uploadID = nil
                            file.activeRevisionDraft = nil

                            do {
                                try self.moc.save()
                                completion(.success(revision))
                            } catch let error {
                                self.moc.rollback()
                                completion(.failure(error))
                            }
                        }

                    case .failure(let error):
                        completion(.failure(error))
                    }
                }

            } catch {
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
        client.postRevision(file.nodeID, shareID: file.shareID) { result in
            onCompletion(result.map { RevisionIdentifier(share: file.shareID, file: file.nodeID, revision: $0.ID) })
        }
    }

}
