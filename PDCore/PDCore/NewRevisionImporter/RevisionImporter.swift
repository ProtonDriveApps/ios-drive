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

    public init(signersKitFactory: SignersKitFactoryProtocol) {
        self.signersKitFactory = signersKitFactory
    }

    public func importNewRevision(from url: URL, into file: File) throws -> File {
        guard let moc = file.moc else { throw File.noMOC() }

        return try moc.performAndWait {
            let coreDataFile = file.in(moc: moc)
            let signersKit = try signersKitFactory.make(forSigner: .main)

            guard coreDataFile.isUploaded() else { throw File.InvalidState(message: "The file should be already uploaded") }

            let uploadID = UUID()
            // Create new Revision
            coreDataFile.uploadID = uploadID
            coreDataFile.clientUID = uploadID.uuidString
            let coreDataRevision = Revision.`import`(id: uploadID.uuidString, url: url, creatorEmail: signersKit.address.email, moc: moc)

            // Relationships
            coreDataRevision.file = coreDataFile // This adds the current coreDataRevision to File's revisions
            coreDataFile.activeRevisionDraft = coreDataRevision
            coreDataFile.state = .uploading

            try moc.saveOrRollback()

            return coreDataFile
        }

    }
}
