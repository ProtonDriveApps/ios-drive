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

protocol FileStorage {
    func importFilesRepresentation(for urls: [URL], parent: Folder, signersKit: SignersKit) throws -> FileImportOutcome
}

extension StorageManager: FileStorage {

    func importFilesRepresentation(for urls: [URL], parent: Folder, signersKit: SignersKit) throws -> FileImportOutcome {
        let moc = backgroundContext
        var successfulDrafts: [FileDraft] = []
        var failedDrafts: [FaultFile] = []

        // If for some reason the complete creation of a file fails at some step,
        // remove the previously created object and add it to the failed drafts array
        moc.performAndWait {
            let parent = parent.in(moc: moc)
            for url in urls {
                do {
                    let fileDraft = try makeFile(from: url, parent: parent, moc: moc, signersKit: signersKit)
                    successfulDrafts.append(fileDraft)
                } catch {
                    failedDrafts.append(FaultFile(url: url, error: error))
                }
            }

            // If saving is not possible, reset context and transform previous successful
            // drafts into failed drafts
            do {
                try moc.save()
            } catch {
                moc.reset()
                let resetDrafts = successfulDrafts.map(\.url).map { FaultFile(url: $0, error: error) }
                successfulDrafts.removeAll()
                failedDrafts.append(contentsOf: resetDrafts)
            }
        }

        return FileImportOutcome(success: successfulDrafts, failure: failedDrafts)
    }

    private func makeFile(from url: URL, parent: Folder, moc: NSManagedObjectContext, signersKit: SignersKit) throws -> FileDraft {
        let newFile: File = new(with: url.lastPathComponent, by: "name", in: moc)
        newFile.id = url.path
        newFile.parentLink = parent
        newFile.shareID = parent.shareID
        newFile.state = .uploading

        newFile.uploadIDURL = url
        let clearName = url.lastPathComponent

        do {
            let clearValidatedName = try clearName.validateNodeName(validator: NameValidations.iosName)
            let nodeCredentials = try newFile.generateNodeKeys(signersKit: signersKit)
            let contentCredentials = try newFile.generateContentKeyPacket(credentials: nodeCredentials, signersKit: signersKit)
            let name = try newFile.encryptName(cleartext: clearValidatedName, signersKit: signersKit)
            let hash = try newFile.hashFilename(cleartext: clearValidatedName)

            newFile.name = name
            newFile.nodeHash = hash
            newFile.nodeKey = nodeCredentials.key
            newFile.nodePassphrase = nodeCredentials.passphrase
            newFile.nodePassphraseSignature = nodeCredentials.signature
            newFile.contentKeyPacket = contentCredentials.contentKeyPacketBase64
            newFile.contentKeyPacketSignature = contentCredentials.contentKeyPacketSignature

            newFile.signatureEmail = signersKit.address.email
            newFile.nameSignatureEmail = signersKit
                .address.email

            newFile.mimeType = url.mimeType()
            newFile.createdDate = Date()
            newFile.modifiedDate = Date()
            newFile.uploadID = UUID()

            return try FileDraft.extract(from: newFile, moc: moc)

        } catch {
            moc.delete(newFile)
            throw error
        }
    }

    struct FileImportError: Error {
        let message: String
    }
}
