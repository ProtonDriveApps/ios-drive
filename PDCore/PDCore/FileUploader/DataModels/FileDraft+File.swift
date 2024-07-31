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

    static func extract(from file: File) throws -> FileDraft {
        let state = getCurrentState(of: file)

        guard file.isPendingUpload else {
            throw AlreadyCommittedFileError()
        }

        // All files that need to be uploaded or photos that have children that need to be uploaded should have an uploadID.
        guard let uploadID = file.uploadID else {
            throw file.invalidState("The file doesn't have an uploadID.")
        }
        let uri = file.objectID.uriRepresentation().absoluteString
        let size = file.size
        let mimeType = MimeType(value: file.mimeType)

        // If the main photo is already commited we produce an empty filedraft that will be interpreted as a parent that has children that need to be uploaded.
        if let photo = file as? Photo, photo.state == .active {
            return FileDraft(uploadID: uploadID, file: file, state: .none, numberOfBlocks: 0, isEmpty: false, uri: uri, size: size, mimeType: mimeType)
        }

        guard let revision = file.activeRevisionDraft else {
            return FileDraft.invalid(withFile: file)
        }

        if state == .encryptingRevision || state == .encryptingNewRevision {
            if let size = try sizeForExistingFile(revision.normalizedUploadableResourceURL) {
                let blocks = Int(ceil(Double(size) / Double(Constants.maxBlockSize)))
                return FileDraft(uploadID: uploadID, file: file, state: state, numberOfBlocks: blocks, isEmpty: blocks == .zero, uri: uri, size: size, mimeType: mimeType)
            } else {
                return FileDraft.invalid(withFile: file)
            }
        } else if state == .creatingFileDraft || state == .creatingNewRevision || state == .uploadingRevision || state == .commitingRevision {
            let blocks = revision.blocks.count
            return FileDraft(uploadID: uploadID, file: file, state: state, numberOfBlocks: blocks, isEmpty: blocks == .zero, uri: uri, size: size, mimeType: mimeType)
        } else {
            return FileDraft(uploadID: UUID(), file: file, state: .none, numberOfBlocks: 0, isEmpty: true, uri: uri, size: size, mimeType: mimeType)
        }
    }

    private static func getCurrentState(of file: File) -> FileDraft.State {
        if file.isEncryptingRevision() {
            return .encryptingRevision
        }

        if file.isCreatingFileDraft() {
            return .creatingFileDraft
        }

        if file.isUploadingRevision() {
            return .uploadingRevision
        }

        if file.isCommitingRevision() {
            return .commitingRevision
        }

        if file.isEncryptingNewRevision() {
            return .encryptingNewRevision
        }

        if file.isCreatingNewRevision() {
            return .creatingNewRevision
        }

        return .none
    }

    private static func sizeForExistingFile(_ url: URL?) throws -> Int? {
        guard let clearContentURL = url else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: clearContentURL.path) else {
            throw ContentCleanedError(area: .cleartext)
        }

        // Since the above confirmed that the URL is valid, receiving `nil` here
        // indicates that the URL is for a folder (e.g. a package resource file).
        //   If it it's important to have the size of the folder's content, this
        // code should calculate the accumulate size of all sub items.
        return clearContentURL.fileSize ?? 0
    }

    static func invalid(withFile file: File) -> FileDraft {
        return FileDraft(uploadID: UUID(), file: file, state: .none, numberOfBlocks: 0, isEmpty: true, uri: "", size: 1, mimeType: .empty)
    }

    public enum State: Equatable {
        case none
        case encryptingRevision
        case encryptingNewRevision
        case creatingFileDraft
        case creatingNewRevision
        case uploadingRevision
        case commitingRevision
    }
}

extension FileDraft {

    func getCreatedRevisionDraft() throws -> CreatedRevisionDraft {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw File.InvalidState(message: "Invalid File, it should have already an activeRevisionDraft")
            }

            guard revision.uploadState == .created else {
                throw Revision.InvalidState(message: "Invalid Revision, the upload state should be `.created`")
            }

            guard let url = revision.normalizedUploadableResourceURL else {
                throw Revision.InvalidState(message: "Invalid Revision, it should have a url that points to the local resource")
            }

            return CreatedRevisionDraft(uploadID: uploadID, localURL: url, size: revision.uploadSize, revision: revision, isEmpty: isEmpty, mimetype: MimeType(value: file.mimeType))
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

    func getUploadableRevision() throws -> Revision {
        guard let revision = file.activeRevisionDraft else {
            throw file.invalidState("No active revision found")
        }

        return revision
    }

    func getNameResolvingFileDraft() throws -> FileDraftUploadableDraft {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard file.isCreatingFileDraft() else {
                throw file.invalidState("The file is not in the correct state")
            }

            guard let parentLink = file.parentLink else {
                throw file.invalidState("Uploadable file draft must have a parent link.")
            }

            let clearParentNodeHashKey = try parentLink.decryptNodeHashKey()

            guard let uploadID = file.uploadID else {
                throw file.invalidState("Uploadable file must have an uploadID.")
            }

            guard let armoredName = file.name else {
                throw file.invalidState("NameChangeDraft must have an encrypted name.")
            }

            guard let contentKeyPacket = file.contentKeyPacket else {
                throw file.invalidState("Uploadable file draft must have a content key packet.")
            }

            guard let contentKeyPacketSignature = file.contentKeyPacketSignature else {
                throw file.invalidState("Uploadable file draft must have a content key packet signature.")
            }
            
            guard let signatureEmail = file.signatureEmail else {
                throw file.invalidState("Uploadable file draft must have a signature email.")
            }

            let filename = try file.decryptName()
            return FileDraftUploadableDraft(
                uploadID: uploadID,
                hash: file.nodeHash,
                clearName: filename,
                armoredName: armoredName,
                nameSignatureAddress: signatureEmail,
                nodeKey: file.nodeKey,
                nodePassphrase: file.nodePassphrase,
                nodePassphraseSignature: file.nodePassphraseSignature,
                contentKeyPacket: contentKeyPacket,
                contentKeyPacketSignature: contentKeyPacketSignature,
                parent: parentLink.identifier,
                parentNodeHashKey: clearParentNodeHashKey,
                mimeType: file.mimeType,
                clientUID: file.clientUID ?? "",
                file: file
            )
        }
    }

    func getFileIdentifier() throws -> NodeIdentifier {
        guard let moc = file.moc else { throw File.noMOC() }

        return moc.performAndWait {
            file.identifier
        }
    }

    func getFileUploadingFileIdentifier() throws -> UploadingFileIdentifier {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard let revision = file.activeRevisionDraft else {
                throw file.invalidState("The file doesn't have a revision draft")
            }

            return UploadingFileIdentifier(nodeId: file.id, shareId: file.shareID, revisionId: revision.id)
        }
    }
}
