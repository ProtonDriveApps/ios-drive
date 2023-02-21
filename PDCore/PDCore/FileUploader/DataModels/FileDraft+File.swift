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

extension FileDraft {

    static func extract(from file: File, moc: NSManagedObjectContext) throws -> FileDraft {
        let draft: FileDraft = try moc.performAndWait {
            let file = file.in(moc: moc)

            // We remove the uploadID when the file is already uploaded
            guard let id = file.uploadID else {
                throw ResumeDraftCreationError.fileAlreadyUploaded
            }

            let state = getCurrentState(of: file)

            // We could have lost the original resource while the file is not yet uploaded
            guard let url = file.uploadIDURL else {
                throw Uploader.Errors.cleartextLost
            }

            try assertContentExistence(state: state, url: url)

            guard let name = file.name,
                  let parentIdentifier = file.parentLink?.identifier,
                  let clearParentNodeHashKey = try? file.parentLink?.decryptNodeHashKey(),
                  let contentKeyPacket = file.contentKeyPacket,
                  let contentKeyPacketSignature = file.contentKeyPacketSignature else {
                      throw ResumeDraftCreationError.corruptedFileData
                  }

            var numberOfBlocks: Int
            if state == .uploadingRevision || state == .sealingRevision || state == .finished {
                numberOfBlocks = file.activeRevisionDraft!.blocks.count
            } else {
                numberOfBlocks = Int(ceil(Double(url.fileSize ?? .zero) / Double(Constants.maxBlockSize)))
            }

            return FileDraft(
                uploadID: id,
                url: url,
                file: file,
                state: state,
                numberOfBlocks: numberOfBlocks,
                parent: .init(
                    identifier: parentIdentifier,
                    nodeHashKey: clearParentNodeHashKey),
                parameters: .init(
                    nodeKey: file.nodeKey,
                    nodePassphrase: file.nodePassphrase,
                    nodePassphraseSignature: file.nodePassphraseSignature,
                    contentKeyPacket: contentKeyPacket,
                    contentKeyPacketSignature: contentKeyPacketSignature,
                    signatureAddress: file.signatureEmail),
                nameParameters: .init(
                    hash: file.nodeHash,
                    clearName: url.lastPathComponent,
                    armoredName: name,
                    nameSignatureAddress: file.signatureEmail
                )
            )
        }

        return draft
    }

    private static func assertContentExistence(state: State, url: URL) throws {
        if state == .uploadingDraft || state == .encryptingRevision {

            // We could have lost the original resource while the file is not yet uploaded
            guard url.path != "/",
                  FileManager.default.fileExists(atPath: url.path) else {
                throw Uploader.Errors.cleartextLost
            }
        }
    }

    private static func getCurrentState(of file: File) -> FileDraft.State {
        guard !file.updatingRevision else { return .updateRevision }

        if let revisionDraft = file.activeRevisionDraft {
            switch revisionDraft.uploadState {
            case .created:
                return .encryptingRevision
            case .encrypted:
                return .uploadingRevision
            case .uploaded:
                return .sealingRevision
            case .none:
                return .finished
            }
        } else {
            return .uploadingDraft
        }
    }

    enum ResumeDraftCreationError: Error {
        case fileAlreadyUploaded
        case draftAlreadyCreated
        case corruptedFileData
    }

}

private extension File {
    /// Having an active revision means that the file has been successfully uploaded and any new attempt of uploading can only mean that we upload a new revision
    var updatingRevision: Bool {
        activeRevision != nil && activeRevisionDraft == nil && uploadID != nil && uploadIDURL != nil
    }
}

extension FileDraft {

    func getUploadableFileDraft() -> UploadableFileDraft {
        UploadableFileDraft(
            shareID: parent.identifier.shareID,
            parentLinkID: parent.identifier.nodeID,
            armoredName: nameParameters.armoredName,
            nameHash: nameParameters.hash,
            nodeKey: parameters.nodeKey,
            nodePassphrase: parameters.nodePassphrase,
            nodePassphraseSignature: parameters.nodePassphraseSignature,
            signatureAddress: parameters.signatureAddress,
            contentKeyPacket: parameters.contentKeyPacket,
            contentKeyPacketSignature: parameters.contentKeyPacketSignature,
            mimeType: mimeType
        )
    }

    func getCreatedRevisionDraft() throws -> CreatedRevisionDraft {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw File.InvalidState(message: "Invalid File, it should have already an activeRevisionDraft")
            }

            return CreatedRevisionDraft(localURL: url, revision: revision)
        }
    }

    func getUploadableRevision() throws -> UploadableRevision {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw File.InvalidState(message: "Invalid File, it should have already an activeRevisionDraft")
            }

            return revision.unsafeUploadableRevision
        }
    }

    func getRequestedUploadForActiveRevisionDraft() throws -> Date {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw file.invalidState("No active revision found")
            }

            guard let requestedUpload = revision.requestedUpload else {
                throw revision.invalidState("Should have the last requested upload date set")
            }

            return requestedUpload
        }
    }

    func getFullUploadableThumbnail() throws -> FullUploadableThumbnail? {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw file.invalidState("No active revision found")
            }

            return revision.unsafeFullUploadableThumbnail
        }
    }

    func getFullUploadableBlocks() throws -> [FullUploadableBlock] {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw file.invalidState("No active revision found")
            }

            return revision.unsafeFullUploadableBlocks
        }
    }

    var unsafeCreatedRevisionDraft: CreatedRevisionDraft? {
        guard let revision = file.activeRevisionDraft else {
            return nil
        }
        return CreatedRevisionDraft(localURL: url, revision: revision)
    }

    func createdRevisionDraft() throws -> CreatedRevisionDraft {
        let createdRevisionDraft: CreatedRevisionDraft = try file.managedObjectContext!.performAndWait {
            guard let revision = unsafeCreatedRevisionDraft else {
                throw Uploader.Errors.blockLacksMetadata
            }
            return revision
        }
        return createdRevisionDraft
    }

    func getSealableRevision() throws -> Revision {
        guard let moc = file.managedObjectContext else {
            throw NSError(domain: "Attempted to get moc from file already deleted for Revision Sealer", code: 0)
        }

        let revision: Revision = try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw NSError(domain: "Revision Sealer invalid state - File has no active revision", code: 0)
            }

            guard revision.uploadState == .uploaded else {
                throw NSError(domain: "Revision Sealer invalid state - Active revision is not uploaded", code: 0)
            }

            return revision
        }

        return revision
    }

}
