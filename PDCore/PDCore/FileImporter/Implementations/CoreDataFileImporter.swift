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

final class CoreDataFileImporter: FileImporter {
    private let moc: NSManagedObjectContext
    private let signersKitFactory: SignersKitFactoryProtocol
    private let uploadClientUIDProvider: UploadClientUIDProvider

    init(moc: NSManagedObjectContext, signersKitFactory: SignersKitFactoryProtocol, uploadClientUIDProvider: UploadClientUIDProvider) {
        self.moc = moc
        self.signersKitFactory = signersKitFactory
        self.uploadClientUIDProvider = uploadClientUIDProvider
    }

    func importFile(from url: URL, to folder: Folder, with localID: String? = nil) throws -> File {
        guard let moc = folder.moc else { throw Folder.noMOC() }
        
        Log.info("STAGE: 0 Batch imported 🗂💾 started", domain: .uploader)
        
        return try moc.performAndWait {
            let parent = folder.in(moc: moc)

            do {
                let newFile = try makeEncryptedImportedFile(url, parent, localID)
                let coreDataFile = File.`import`(newFile, moc: moc)
                coreDataFile.parentFolder = folder
                try moc.saveOrRollback()

                Log.info("STAGE: 0 Batch imported 🗂💾 finished ✅", domain: .uploader)

                return coreDataFile
            } catch {
                moc.rollback()

                try? FileManager.default.removeItem(at: url)

                Log.info("STAGE: 0 Batch imported 🗂💾 finished ❌", domain: .uploader)
                Log.error("Batch import failed", error: error, domain: .uploader)

                throw error
            }
        }
    }

    private func makeEncryptedImportedFile(_ url: URL, _ folder: Folder, _ localID: String? = nil) throws -> EncryptedImportedFile {
#if os(macOS)
        let signersKit = try generateSignersKit()
#else
        let addressID = try folder.getContextShareAddressID()
        let signersKit = try signersKitFactory.make(forAddressID: addressID)
#endif
        let clientUID = uploadClientUIDProvider.getUploadClientUID()
        let parent = try folder.encrypting()

        let uuid = UUID()
        let originalFileName = url.lastPathComponent
        let clearValidatedName = try originalFileName.validateNodeName(validator: NameValidations.iosName)

        let encryptedName = try Encryptor.encryptAndSign(clearValidatedName, key: parent.nodeKey, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
        let hash = try Encryptor.hmac(filename: clearValidatedName, parentHashKey: parent.hashKey)

        let nodeKeyPack = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: parent.nodeKey)
        let contentKeyPacket = try Encryptor.generateContentKeys(nodeKey: nodeKeyPack.key, nodePassphrase: nodeKeyPack.passphraseRaw)

        return EncryptedImportedFile(
            name: encryptedName,
            hash: hash,
            mimeType: url.mimeType(),
            size: try url.getFileSize(),
            nodeKey: nodeKeyPack.key,
            nodePassphrase: nodeKeyPack.passphrase,
            nodePassphraseSignature: nodeKeyPack.signature,
            signatureAddress: signersKit.address.email,
            contentKeyPacket: contentKeyPacket.contentKeyPacketBase64,
            contentKeyPacketSignature: contentKeyPacket.contentKeyPacketSignature,
            parentLinkID: parent.id,
            clientUID: clientUID,
            isInheritingOfflineAvailable: parent.availableOffline,
            shareID: parent.shareID,
            volumeID: parent.volumeID,
            uploadID: uuid,
            resourceURL: url,
            localID: localID
        )
    }

    private func generateSignersKit() throws -> SignersKit {
        try signersKitFactory.make(forSigner: .main)
    }
}
