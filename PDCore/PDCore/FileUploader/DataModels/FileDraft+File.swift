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

    static func extract(from file: File, moc: NSManagedObjectContext) -> FileDraft {
        let state = getCurrentState(of: file)
        
        var numberOfBlocks: Int
        if state == .creatingFileDraft || state == .creatingNewRevision || state == .uploadingRevision || state == .commitingRevision {
            numberOfBlocks = file.activeRevisionDraft!.blocks.count
        } else if state == .encryptingRevision || state == .encryptingNewRevision {
            let url = file.activeRevisionDraft?.uploadableResourceURL
            numberOfBlocks = Int(ceil(Double(url?.fileSize ?? .zero) / Double(Constants.maxBlockSize)))
        } else {
            numberOfBlocks = .zero
        }
        
        let id = file.uploadID!
        return FileDraft(
            uploadID: id,
            file: file,
            state: state,
            numberOfBlocks: numberOfBlocks
        )
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

            guard let url = revision.uploadableResourceURL else {
                throw Revision.InvalidState(message: "Invalid Revision, it should have a url that points to the local resource")
            }

            return CreatedRevisionDraft(localURL: url, revision: revision)
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

            guard let armoredName = file.name else {
                throw file.invalidState("NameChangeDraft must have an encrypted name.")
            }

            guard let contentKeyPacket = file.contentKeyPacket else {
                throw file.invalidState("Uploadable file draft must have a content key packet.")
            }

            guard let contentKeyPacketSignature = file.contentKeyPacketSignature else {
                throw file.invalidState("Uploadable file draft must have a content key packet signature.")
            }

            return FileDraftUploadableDraft(
                hash: file.nodeHash,
                clearName: file.decryptedName,
                armoredName: armoredName,
                nameSignatureAddress: file.signatureEmail,
                nodeKey: file.nodeKey,
                nodePassphrase: file.nodePassphrase,
                nodePassphraseSignature: file.nodePassphraseSignature,
                contentKeyPacket: contentKeyPacket,
                contentKeyPacketSignature: contentKeyPacketSignature,
                parent: parentLink.identifier,
                parentNodeHashKey: clearParentNodeHashKey,
                mimeType: file.mimeType,
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
}
