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

import CoreData

extension File {
    /// Create a new File from the `EncryptedImportedFile` model
    static func `import`(_ file: EncryptedImportedFile, moc: NSManagedObjectContext) -> File {
        // Create new File
        let coreDataFile: File = NSManagedObject.newWithValue(file.uploadID.uuidString, by: "id", in: moc)
        coreDataFile.name = file.name
        coreDataFile.nodeHash = file.hash
        coreDataFile.mimeType = file.mimeType
        coreDataFile.size = file.size
        coreDataFile.nodeKey = file.nodeKey
        coreDataFile.nodePassphrase = file.nodePassphrase
        coreDataFile.nodePassphraseSignature = file.nodePassphraseSignature
        coreDataFile.contentKeyPacket = file.contentKeyPacket
        coreDataFile.contentKeyPacketSignature = file.contentKeyPacketSignature
        coreDataFile.clientUID = file.clientUID
        coreDataFile.localID = file.localID

        coreDataFile.setShareID(file.shareID)
        coreDataFile.volumeID = file.volumeID
        coreDataFile.signatureEmail = file.signatureAddress
        coreDataFile.nameSignatureEmail = file.signatureAddress
        coreDataFile.state = .interrupted

        #if os(macOS)
        coreDataFile.isInheritingOfflineAvailable = file.isInheritingOfflineAvailable
        #endif

        coreDataFile.uploadID = file.uploadID
        coreDataFile.createdDate = Date()
        coreDataFile.modifiedDate = Date()

        // Create new Revision
        let coreDataRevision = Revision.`import`(
            id: file.uploadID.uuidString,
            volumeID: file.volumeID,
            url: file.resourceURL,
            size: file.size,
            creatorEmail: file.signatureAddress,
            moc: moc
        )

        // Relationships
        coreDataRevision.file = coreDataFile // This adds the current coreDataRevision to File's revisions
        coreDataFile.activeRevisionDraft = coreDataRevision

        return coreDataFile
    }
}

// swiftlint:disable function_parameter_count
extension Revision {
    /// Create a new Revision with the provided id
    static func `import`(id: String, volumeID: String, url: URL, size: Int, creatorEmail: String, moc: NSManagedObjectContext) -> Revision {
        let coreDataRevision: Revision = NSManagedObject.newWithValue(id, by: "id", in: moc)
        coreDataRevision.uploadState = .created
        coreDataRevision.uploadSize = size
        coreDataRevision.normalizedUploadableResourceURL = url
        coreDataRevision.signatureAddress = creatorEmail
        coreDataRevision.volumeID = volumeID

        return coreDataRevision
    }
}
// swiftlint:enable function_parameter_count
