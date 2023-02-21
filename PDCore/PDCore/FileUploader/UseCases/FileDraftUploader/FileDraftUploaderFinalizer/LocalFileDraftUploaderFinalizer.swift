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

struct LocalFileDraftUploaderFinalizer: FileDraftUploaderFinalizer {
    let draft: FileDraft
    let storage: StorageFileDraftUploaderFinalizer
    let xAttributesCreator: ExtendedAttributesCreator

    func finalize(_ uploaded: RemoteUploadedNewFile) throws {
        let xAttributes = try xAttributesCreator.make(
            nodeKey: uploaded.nodeKey,
            addressKey: uploaded.addressPrivateKey,
            addressPassphrase: uploaded.addressPassphrase
        )

        try storage.finalizeFileDraft(draft.file, uploaded: uploaded, xAttributes: xAttributes)
    }
}

protocol StorageFileDraftUploaderFinalizer {
    func finalizeFileDraft(_ file: File, uploaded: RemoteUploadedNewFile, xAttributes: String) throws
}

extension StorageManager: StorageFileDraftUploaderFinalizer {

    func finalizeFileDraft(_ file: File, uploaded: RemoteUploadedNewFile, xAttributes: String) throws {
        try backgroundContext.performAndWait {
            let file = file.in(moc: self.backgroundContext)

            file.id = uploaded.fileID
            file.name = uploaded.armoredName
            file.nodeHash = uploaded.nameHash

            file.clearName = nil
            self.forceNameUpdateInMainContext(for: file)

            let revision: Revision = self.unique(with: Set([uploaded.revisionID]), in: self.backgroundContext).first!
            revision.uploadState = .created
            revision.xAttributes = xAttributes

            file.activeRevisionDraft = revision
            file.addToRevisions(revision)
            file.state = .uploading

            do {
                try self.backgroundContext.save()
            } catch {
                self.backgroundContext.rollback()
                throw error
            }
        }
    }

    private func forceNameUpdateInMainContext(for file: File) {
        mainContext.perform {
            let mainContextFile = file.in(moc: self.mainContext)
            mainContextFile.clearName = nil
        }
    }

}
