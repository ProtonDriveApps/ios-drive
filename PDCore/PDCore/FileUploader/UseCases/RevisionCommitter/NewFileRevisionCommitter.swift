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

final class NewFileRevisionCommitter: RevisionCommitter {
    
    private let cloudRevisionCommiter: CloudRevisionCommiter
    private let signersKitFactory: SignersKitFactoryProtocol
    private let moc: NSManagedObjectContext

    private var isCancelled = false

    init(
        cloudRevisionCommiter: CloudRevisionCommiter,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.cloudRevisionCommiter = cloudRevisionCommiter
        self.signersKitFactory = signersKitFactory
        self.moc = moc
    }

    func commit(_ draft: FileDraft, completion: @escaping Completion) {
        guard !isCancelled else { return }

        do {
            let commitableRevision = try getCommitableRevision(from: draft.file)

            cloudRevisionCommiter.commit(commitableRevision) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success:
                    self.finalizeRevision(in: draft.file, commitableRevision: commitableRevision, completion: completion)

                case .failure(let error as ResponseError) where CommitPolicy.invalidRevision.contains(error.responseCode):
                    self.rollbackUploadedStatus(in: draft.file)
                    completion(.failure(error))

                case .failure(let error):
                    completion(.failure(error))
                }
            }

        } catch {
            completion(.failure(error))
        }
    }

    private func getCommitableRevision(from file: File) throws -> CommitableRevision {
        return try moc.performAndWait {
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

            var partialContentHashes: [Data] = []
            if let uploadedThumbnail = revision.thumbnail?.asUploadedThumbnail{
                partialContentHashes.append(uploadedThumbnail.sha256)
            }
            let contentHashes = uploadedBlocks.reduce(into: partialContentHashes) { $0.append($1.sha256) }

            let manifestSignature = try Encryptor.sign(
                list: Data(contentHashes.joined()),
                addressKey: addressKey,
                addressPassphrase: addressPassphrase
            )

            return CommitableRevision(
                shareID: revision.file.shareID,
                fileID: revision.file.id,
                revisionID: revision.id,
                blockList: uploadedBlocks.map { CommitableBlock(index: $0.index, token: $0.token) },
                manifestSignature: manifestSignature,
                signatureAddress: signatureAddress,
                xAttributes: revision.xAttributes
            )
        }
    }

    func finalizeRevision(in file: File, commitableRevision: CommitableRevision, completion: @escaping Completion) {
        moc.performAndWait {
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

            do {
                try moc.saveOrRollback()
                /// Perform immediately after saving 🚨, to ensure that there are no changes to the object’s relationships.
                /// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/FaultingandUniquing.html
                self.moc.refresh(revision, mergeChanges: false)
                completion(.success)
            } catch let error {
                completion(.failure(error))
            }
        }
    }

    func rollbackUploadedStatus(in file: File) {
        moc.performAndWait {
            file.activeRevisionDraft?.unsetUploadedState()
            try? moc.saveOrRollback()
        }
    }

    func cancel() {
        isCancelled = true
    }
}

// MARK: - DTOs
struct UploadedBlock {
    let index: Int
    let token: String
    let sha256: Data
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
        return UploadedBlock(index: index, token: token, sha256: sha256)
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
        thumbnail?.unsetUploadedState()
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
