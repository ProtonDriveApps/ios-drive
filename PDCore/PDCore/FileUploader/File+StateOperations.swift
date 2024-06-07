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

extension File {
    @objc func handleExpiredRemoteRevisionDraftReference() {
        guard let moc = moc else {
            return
        }

        moc.performAndWait {
            let newUploadID = getUploadID()
            state = (self is Photo) ? .interrupted : .paused
            uploadID = newUploadID
            id = newUploadID.uuidString
            clientUID = clientUID ?? ""
            activeRevisionDraft?.id = newUploadID.uuidString
            activeRevisionDraft?.unsetUploadedState()
            try? moc.saveOrRollback()
        }
    }

    func getUploadID() -> UUID {
        if let uploadID = uploadID {
            return uploadID
        } else {
            let newUploadID = UUID()
            Log.info("🪪 \(id) will get uploadID: \(newUploadID)", domain: .uploader)
            return newUploadID
        }
    }

    /// Only use if there is at least one revision besides the one being uploaded.
    /// If you wish to delete the initial revision, please use `deleteUploadingFile()`
    /// to delete not only the revision but also the whole file.
    public func prepareForNewUpload() {
        guard let moc = moc else { return }

        moc.performAndWait {
            guard let activeRevisionDraft, self.activeRevision.isNotNil, !self.revisions.isEmpty else {
                Log.error("Attempted to delete revision of file without any completed revisions", domain: .uploader)
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

    public func delete() {
        guard let moc = moc else {
            return
        }
        moc.performAndWait {
            moc.delete(self)
            try? moc.saveIfNeeded()
        }
    }

    func makeUploadableAgain() {
        guard let moc = moc else {
            return
        }
        moc.perform {
            self.isUploading = false
        }
    }
}

extension Revision {

    func clearUnencryptedContents() {
        do {
            guard let url = normalizedUploadableResourceURL else { return }
            try FileManager.default.removeItemIncludingUniqueDirectory(at: url)
        } catch {
            Log.error(DriveError("A file couldn’t be removed.").localizedDescription, domain: .uploader)
        }
    }
}
