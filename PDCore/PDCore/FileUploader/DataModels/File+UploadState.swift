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

// swiftlint:disable unused_optional_binding
public extension File {
    var isUploadable: Bool {
        uploadID != nil
    }

    /// Asserts if this File is a new file, as it comes out from the `CoreDataFileImporter`.
    /// At this points it needs to have its Revision skeleton populated.
    func isEncryptingRevision() -> Bool {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = clientUID,
              let _ = nameSignatureEmail,
              let uploadID = uploadID?.uuidString,
              id == uploadID,
              let activeRevisionDraft = activeRevisionDraft,
              activeRevisionDraft.id == uploadID,
              activeRevisionDraft.uploadState == .created,
              activeRevisionDraft.normalizedUploadableResourceURL.isNotNil,
              revisions == [activeRevisionDraft],
              activeRevision.isNil  else {
            return false
        }
        return true
    }

    /// Asserts if this File is a new file, with a valid local Revision already populated.
    /// At this point it a File draft and a Revision draft need to be created in the BE.
    func isCreatingFileDraft() -> Bool {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = clientUID,
              let _ = nameSignatureEmail,
              let uploadID = uploadID?.uuidString,
              id == uploadID,
              let activeRevisionDraft = activeRevisionDraft,
              activeRevisionDraft.id == uploadID,
              activeRevisionDraft.uploadState == .encrypted,
              activeRevisionDraft.normalizedUploadableResourceURL.isNil,
              revisions == [activeRevisionDraft],
              activeRevision.isNil else {
            return false
        }
        return true
    }

    /// Asserts if the file has a local populated Revision and a Revision draft in the BE.
    /// At this point it needs to upload the local contents of the local revision to the BE.
    func isUploadingRevision() -> Bool {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = clientUID,
              let _ = nameSignatureEmail,
              let uploadID = uploadID?.uuidString,
              id != uploadID,
              let activeRevisionDraft = activeRevisionDraft,
              activeRevisionDraft.id != uploadID,
              activeRevisionDraft.uploadState == .encrypted,
              activeRevisionDraft.normalizedUploadableResourceURL.isNil,
              revisions.contains(activeRevisionDraft) else {
            return false
        }
        return true
    }

    /// Asserts if the file has already Revision draft in the BE ready to be marked as the new active Revision.
    /// At this point it needs to send the manifest signature to the BE.
    func isCommitingRevision() -> Bool {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = clientUID,
              let _ = nameSignatureEmail,
              let uploadID = uploadID?.uuidString,
              id != uploadID,
              let activeRevisionDraft = activeRevisionDraft,
              activeRevisionDraft.id != uploadID,
              activeRevisionDraft.uploadState == .uploaded,
              activeRevisionDraft.normalizedUploadableResourceURL.isNil,
              revisions.contains(activeRevisionDraft) else {
            return false
        }
        return true
    }

    /// Asserts if the file is not a new File and has at least one active Revision and a local skeleton of a new Revision.
    /// At this point it needs to populate locally the skeleton of the new Revision.
    func isEncryptingNewRevision() -> Bool {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = clientUID,
              let _ = nameSignatureEmail,
              let uploadID = uploadID?.uuidString,
              let activeRevisionDraft = activeRevisionDraft,
              activeRevisionDraft.id == uploadID,
              activeRevisionDraft.uploadState == .created,
              activeRevisionDraft.normalizedUploadableResourceURL.isNotNil,
              revisions.contains(activeRevisionDraft),
              activeRevision.isNotNil  else {
            return false
        }
        return true
    }

    /// Asserts if the file is not a new File and has at least one active Revision and a local populated  new Revision.
    /// At this point it needs to create a new Revision draft for the file in the BE.
    func isCreatingNewRevision() -> Bool {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = clientUID,
              let _ = nameSignatureEmail,
              let uploadID = uploadID?.uuidString,
              id != uploadID,
              let activeRevisionDraft = activeRevisionDraft,
              activeRevisionDraft.id == uploadID,
              activeRevisionDraft.uploadState == .encrypted,
              activeRevisionDraft.normalizedUploadableResourceURL.isNil,
              revisions.contains(activeRevisionDraft),
              activeRevision.isNotNil else {
            return false
        }
        return true
    }

    /// Asserts if the file has already Revision draft in the BE ready to be marked as the new active Revision.
    /// At this point it needs to send the manifest signature to the BE.
    func isUploaded() -> Bool {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = nameSignatureEmail,
              uploadID == nil,
              activeRevisionDraft == nil,
              !revisions.isEmpty else {
            return false
        }
        return true
    }

    /// Gives an uploadID only if at least one revision has already been uploaded and there is a new revision draft.
    func uploadIDIfUploadingNewRevision() -> UUID? {
        guard let _ = name,
              let _ = contentKeyPacket,
              let _ = contentKeyPacketSignature,
              let _ = nameSignatureEmail,
              let uploadID,
              let _ = activeRevisionDraft,
              !revisions.isEmpty,
              activeRevision.isNotNil else {
            return nil
        }
        return uploadID
    }
    
    func isDraft() -> Bool {
        guard let activeRevisionDraft,
              activeRevision == nil,
              revisions.count == 1,
              revisions.contains(activeRevisionDraft)
        else {
            return false
        }
        return true
    }
}
// swiftlint:enable unused_optional_binding
