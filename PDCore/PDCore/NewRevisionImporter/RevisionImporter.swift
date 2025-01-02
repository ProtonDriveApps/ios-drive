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
import Foundation

public protocol RevisionImporter {
    func importNewRevision(from url: URL, into file: File) throws -> File
}

public class CoreDataRevisionImporter: RevisionImporter {
    private let signersKitFactory: SignersKitFactoryProtocol
    private let uploadClientUIDProvider: UploadClientUIDProvider

    public init(signersKitFactory: SignersKitFactoryProtocol, uploadClientUIDProvider: UploadClientUIDProvider) {
        self.signersKitFactory = signersKitFactory
        self.uploadClientUIDProvider = uploadClientUIDProvider
    }

    public func importNewRevision(from url: URL, into file: File) throws -> File {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            let coreDataFile = file.in(moc: moc)
#if os(macOS)
            let signersKit = try signersKitFactory.make(forSigner: .main)
#else
            let addressID = try file.getContextShareAddressID()
            let signersKit = try signersKitFactory.make(forAddressID: addressID)
#endif

            guard coreDataFile.isUploaded() else { throw File.InvalidState(message: "The file should be already uploaded") }

            let uploadID = UUID()
            let fileSize = try url.getFileSize()
            // Create new Revision
            coreDataFile.uploadID = uploadID
            coreDataFile.clientUID = uploadClientUIDProvider.getUploadClientUID()
            let coreDataRevision = Revision.`import`(id: uploadID.uuidString, volumeID: coreDataFile.volumeID, url: url, size: fileSize, creatorEmail: signersKit.address.email, moc: moc)

            // Relationships
            coreDataRevision.file = coreDataFile // This adds the current coreDataRevision to File's revisions
            coreDataFile.activeRevisionDraft = coreDataRevision
            coreDataFile.state = .uploading

            try moc.saveOrRollback()

            return coreDataFile
        }

    }
}
