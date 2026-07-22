// Copyright (c) 2026 Proton AG
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

public extension CoreDataFile {
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
    
    /// Only use if there is at least one revision besides the one being uploaded.
    /// If you wish to delete the initial revision, please use `deleteUploadingFile()`
    /// to delete not only the revision but also the whole file.
    public func prepareForNewUpload() {
        guard let moc = moc else { return }
        
        moc.performAndWait {
            guard let activeRevisionDraft, self.activeRevision.isNotNil, !self.revisions.isEmpty else {
                Log.error("Attempted to delete revision of file without any completed revisions", error: nil, domain: .uploader)
                assertionFailure("Attempted to delete revision of file without any completed revisions")
                return
            }
            
            self.state = .active
            
            self.uploadID = nil
            moc.delete(activeRevisionDraft)
            self.activeRevisionDraft = nil
            self.clientUID = nil
            
            try? moc.saveOrRollback()
        }
    }
}
