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
import CoreData

class NewFileRevisionCommitter: RevisionCommitter {
    
    let cloudRevisionCommitter: CloudRevisionCommitter
    let uploadedRevisionChecker: UploadedRevisionChecker
    let signersKitFactory: SignersKitFactoryProtocol
    let moc: NSManagedObjectContext

    var isCancelled = false

    init(
        cloudRevisionCommitter: CloudRevisionCommitter,
        uploadedRevisionChecker: UploadedRevisionChecker,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.cloudRevisionCommitter = cloudRevisionCommitter
        self.uploadedRevisionChecker = uploadedRevisionChecker
        self.signersKitFactory = signersKitFactory
        self.moc = moc
    }

    func commit(_ draft: FileDraft, completion: @escaping Completion) {
        guard !isCancelled else { return }

        do {
            try draft.assertIsCommitingRevision(in: moc)
            let revisionAndDigest = try getCommitableRevision(from: draft.file)
            let commitableRevision = revisionAndDigest.commitableRevision

            cloudRevisionCommitter.commit(commitableRevision) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success:
                    self.finalizeRevision(in: draft.file, commitableRevision: commitableRevision, completion: completion)

                case .failure(let error as ResponseError) where CommitPolicy.revisionAlreadyCommittedErrors.contains(error.responseCode):
                    self.checkFileIsUploadedCorrectly(draft, localSHA1: revisionAndDigest.sha1, identifier: revisionAndDigest.identifier, commitableRevision: commitableRevision, completion: completion)

                case .failure(let error as ResponseError) where CommitPolicy.invalidRevision.contains(error.responseCode):
                    self.rollbackUploadedStatus(in: draft.file)
                    completion(.failure(error))

                case .failure(let error as ResponseError) where CommitPolicy.quotaExceeded.contains(error.responseCode):
                    draft.file.changeUploadingState(to: .cloudImpediment)
                    completion(.failure(FileUploaderError.insuficientSpace))

                case .failure(let error):
                    completion(.failure(error))
                }
            }

        } catch {
            completion(.failure(error))
        }
    }

    func checkFileIsUploadedCorrectly(_ draft: FileDraft, localSHA1: String?, identifier: RevisionIdentifier, commitableRevision: CommitableRevision, completion: @escaping Completion ) {
        uploadedRevisionChecker.checkUploadedRevision(identifier) { [weak self] result in
            guard let self, !self.isCancelled else { return }

            switch result {
            case .success(let xAttributesRemote):
                self.moc.performAndWait { [weak self] in
                    guard let self, !self.isCancelled else { return }
                    do {
                        // We use the keys of the local revision for faster results
                        let file = draft.file
                        let filePassphrase = try file.decryptPassphrase()
                        let nodeDecryptionKey = DecryptionKey(privateKey: file.nodeKey, passphrase: filePassphrase)
                        let addressKeys = try file.activeRevisionDraft?.getAddressPublicKeysOfRevisionCreator() ?? []

                        let decryptedRemote = try Decryptor.decryptAndVerifyXAttributes(
                            xAttributesRemote,
                            decryptionKey: nodeDecryptionKey,
                            verificationKeys: addressKeys
                        ).decrypted()
                        let xAttrRemote = try JSONDecoder().decode(ExtendedAttributes.self, from: decryptedRemote)

                        let remoteSHA1 = xAttrRemote.common?.digests?.sha1

                        if remoteSHA1 == localSHA1 {
                            self.finalizeRevision(in: draft.file, commitableRevision: commitableRevision, completion: completion)
                        } else {
                            completion(.failure(UploadedRevisionCheckerError.xAttrsDoNotMatch))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getCommitableRevision(from file: File) throws -> RevisionAndDigest {
        return try moc.performAndWait {
            // The file could have just been uploaded and it's state updated by the events system.
            guard file.state != .active else {
                throw AlreadyCommittedFileError()
            }

            guard let revision = file.activeRevisionDraft else {
                throw file.invalidState("File should have an active revision draft.")
            }

            guard let email = revision.signatureAddress else {
                throw revision.invalidState("Active revision draft has no signature email.")
            }

            guard revision.uploadState == .uploaded else {
                throw revision.invalidState("Active revision draft is not uploaded")
            }

            let signersKit = try signersKitFactory.make(forSigner: .address(email))
            let addressKey = signersKit.addressKey.privateKey
            let addressPassphrase = signersKit.addressPassphrase
            let signatureAddress = signersKit.address.email

            let uploadedBlocks = revision.uploadedBlocks().compactMap(\.asUploadedBlock)
            let uploadedThumbnails = revision.uploadedThumbnails().compactMap(\.asUploadedThumbnail)

            let partialHashes = uploadedThumbnails.reduce(into: []) { $0.append($1.sha256) }
            let contentHashes = uploadedBlocks.reduce(into: partialHashes) { $0.append($1.sha256) }

            let manifestSignature = try Encryptor.sign(
                list: Data(contentHashes.joined()),
                addressKey: addressKey,
                addressPassphrase: addressPassphrase
            )

            let expectedBlockSizes = revision.uploadSize.split(divisor: Constants.maxBlockSize)
            let expectedBlockCount = expectedBlockSizes.count

            // A safeguard to ensure the number of blocks used to generate the manifest
            // match the number of expected blocks when initially provided the file URL
            guard expectedBlockCount == uploadedBlocks.count else {
                throw UploadedRevisionCheckerError.blockUploadCountIncorrect
            }

            // A safeguard to ensure that the size of each block matches the expected block
            // sizes based on the initial file URL
            for (block, expectedSize) in zip(uploadedBlocks, expectedBlockSizes) {
                guard block.clearSize != .zero else {
                    throw UploadedRevisionCheckerError.blockUploadEmpty
                }
                guard block.clearSize == expectedSize else {
                    throw UploadedRevisionCheckerError.blockUploadSizeIncorrect
                }
            }

            let photo = try getPhotoIfNeeded(revision: revision)

            let commitableRevision = CommitableRevision(
                shareID: revision.file.shareID,
                fileID: revision.file.id,
                revisionID: revision.id,
                blockList: uploadedBlocks.map { CommitableBlock(index: $0.index, token: $0.token) },
                manifestSignature: manifestSignature,
                signatureAddress: signatureAddress,
                xAttributes: revision.xAttributes,
                photo: photo
            )
            let identifier = RevisionIdentifier(share: commitableRevision.shareID, file: commitableRevision.fileID, revision: commitableRevision.revisionID)
            let sha1 = try? revision.decryptedExtendedAttributes().common?.digests?.sha1

            return RevisionAndDigest(commitableRevision: commitableRevision, identifier: identifier, sha1: sha1)
        }
    }

    func getPhotoIfNeeded(revision: Revision) throws -> CommitableRevision.Photo? {
        return nil
    }

    func finalizeRevision(in file: File, commitableRevision: CommitableRevision, completion: @escaping Completion) {
        moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { return }
            
            guard let revision = file.activeRevisionDraft else {
                return completion(.failure(file.invalidState("File should have an active revision draft.")))
            }

            revision.created = Date()
            revision.manifestSignature = commitableRevision.manifestSignature
            revision.state = .active

            file.activeRevision = revision
            file.addToRevisions(revision)
            file.size = revision.size
            file.state = .active

            file.uploadID = nil
            file.activeRevisionDraft = nil
            file.clientUID = nil

            notifyParentIfNeeded(file: file)
            
            do {
                try moc.saveOrRollback()
                // Perform immediately after saving 🚨, to ensure that there are no changes to the object’s relationships.
                // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/FaultingandUniquing.html
                self.moc.refresh(revision, mergeChanges: false)
                completion(.success)
            } catch let error {
                completion(.failure(error))
            }
        }
    }

    /// Template method that allow the notification to the parent if there are changes, not relevant for regular files
    func notifyParentIfNeeded(file _: File) { }

    func rollbackUploadedStatus(in file: File) {
        moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { return }
            
            file.activeRevisionDraft?.unsetUploadedState()
            try? moc.saveOrRollback()
        }
    }

    func cancel() {
        isCancelled = true
    }
}

struct RevisionAndDigest {
    let commitableRevision: CommitableRevision
    let identifier: RevisionIdentifier
    let sha1: String?
}

// MARK: - DTOs
struct UploadedBlock {
    let index: Int
    let token: String
    let sha256: Data
    let clearSize: Int
}

struct UploadedThumbnail {
    let sha256: Data
}

extension UploadBlock {
    var asUploadedBlock: UploadedBlock? {
        guard isUploaded,
              let token = uploadToken else {
            return nil
        }
        return UploadedBlock(index: index, token: token, sha256: sha256, clearSize: clearSize)
    }
}

extension Thumbnail {
    var asUploadedThumbnail: UploadedThumbnail? {
        guard isUploaded,
              let sha256 = sha256 else {
            return nil
        }
        return UploadedThumbnail(sha256: sha256)
    }
}

// MARK: - Cleanup state
extension Revision {
    func unsetUploadedState() {
        uploadState = .encrypted
        unsetUploadedStateForAllBlocks()
        unsetUploadedStateForThumbnail()
    }

    func unsetUploadedStateInBlock(atIndex index: Int) {
        blocks.first(where: { $0.index == index })?.asUploadBlock?.unsetUploadedState()
    }

    func unsetUploadedStateForAllBlocks() {
        blocks.compactMap(\.asUploadBlock).forEach { $0.unsetUploadedState() }
    }

    func unsetUploadedStateForThumbnail() {
        thumbnails.forEach { $0.unsetUploadedState() }
    }
}

extension UploadBlock {
    func unsetUploadedState() {
        self.isUploaded = false
        unsetUploadableState()
    }

    func unsetUploadableState() {
        self.uploadUrl = nil
        self.uploadToken = nil
    }
}

extension Thumbnail {
    func unsetUploadedState() {
        self.isUploaded = false
        unsetUploadableState()
    }

    func unsetUploadableState() {
        self.uploadURL = nil
    }
}
