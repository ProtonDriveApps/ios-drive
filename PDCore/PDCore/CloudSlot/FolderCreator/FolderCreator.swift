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

import PDClient
import CoreData

public class FolderCreator {
    /// Typealias for one of the methods of PDCLient's Client.
    public typealias CloudFolderCreator = (Client.ShareID, NewFolderParameters) async throws -> NewFolder

    private let moc: NSManagedObjectContext
    private let storage: StorageManager
    private let signersKitFactory: SignersKitFactoryProtocol
    private let cloudFolderCreator: CloudFolderCreator

    public init(
        storage: StorageManager,
        cloudFolderCreator: @escaping CloudFolderCreator,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.moc = moc
        self.storage = storage
        self.signersKitFactory = signersKitFactory
        self.cloudFolderCreator = cloudFolderCreator
    }

    /// Creates a new folder with the specified name under a given parent folder.
    ///
    /// This method performs cryptographic operations for secure folder creation, including
    /// key generation and data encryption. It interacts with cloud services to create the folder
    /// and manages the local Core Data storage.
    ///
    /// - Parameters:
    ///   - name: The name of the new folder to be created.
    ///   - parent: The parent `Folder` under which the new folder will be created.
    /// - Returns: An asynchronously created `Folder` instance representing the new folder.
    /// - Throws: An error if any part of the folder creation process fails.
    public func createFolder(_ name: String, parent: Folder) async throws -> Folder {
        let clearValidatedName = try name.validateNodeName(validator: NameValidations.iosName)

        let (parentFolder, signersKit) = try await moc.perform {
            let parent = parent.in(moc: self.moc)
#if os(macOS)
            let signersKit = try self.signersKitFactory.make(forSigner: .main)
#else
            let addressID = try parent.getContextShareAddressID()
            let signersKit = try self.signersKitFactory.make(forAddressID: addressID)
#endif
            let parentFolder = try parent.encrypting()
            return (parentFolder, signersKit)
        }

        let encryptedName = try Encryptor.encryptAndSign(clearValidatedName, key: parentFolder.nodeKey, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
        let nameHash = try Encryptor.hmac(filename: clearValidatedName, parentHashKey: parentFolder.hashKey)

        let nodeKeyPack = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: parentFolder.nodeKey)
        let hashKey = try Encryptor.generateNodeHashKey(nodeKey: nodeKeyPack.key, passphrase: nodeKeyPack.passphraseRaw)

        let createdFolder = CreatedFolder(volumeID: parentFolder.volumeID, shareID: parentFolder.shareID, name: encryptedName, nameSignatureEmail: signersKit.address.email, nameHash: nameHash, nodeKey: nodeKeyPack.key, nodePassphrase: nodeKeyPack.passphrase, nodePassphraseSignature: nodeKeyPack.signature, nodeHashKey: hashKey)

        let parameters = NewFolderParameters(
            name: createdFolder.name,
            hash: createdFolder.nameHash,
            parentLinkID: parentFolder.id,
            folderKey: createdFolder.nodeKey,
            folderHashKey: createdFolder.nodeHashKey,
            nodePassphrase: createdFolder.nodePassphrase,
            nodePassphraseSignature: createdFolder.nodePassphraseSignature,
            signatureAddress: createdFolder.nameSignatureEmail // The same as the one for the passphrase signature, BE does not yet accept two signatures
        )

        let newFolderID = try await cloudFolderCreator(parentFolder.shareID, parameters).ID

        return try await moc.perform {
            let newFolder = Folder.make(from: createdFolder, id: newFolderID, moc: self.moc)
            newFolder.parentLink = parent.in(moc: self.moc)

            try self.moc.saveOrRollback()

            return newFolder
        }
    }
}

private struct CreatedFolder {
    let volumeID: String
    let shareID: String

    let name: String
    let nameSignatureEmail: String
    let nameHash: String

    let nodeKey: String
    let nodePassphrase: String
    let nodePassphraseSignature: String
    let nodeHashKey: String
}

private extension Folder {
    /// Create a new File from the `EncryptedImportedFile` model
    static func make(from createdFolder: CreatedFolder, id: String, moc: NSManagedObjectContext) -> Folder {
        // Create new Folder
        let coreDataFolder = Folder.fetchOrCreate(id: id, volumeID: createdFolder.volumeID, in: moc)
        coreDataFolder.setShareID(createdFolder.shareID)

        coreDataFolder.name = createdFolder.name
        coreDataFolder.nameSignatureEmail = createdFolder.nameSignatureEmail
        coreDataFolder.nodeHash = createdFolder.nameHash

        coreDataFolder.nodeKey = createdFolder.nodeKey
        coreDataFolder.nodePassphrase = createdFolder.nodePassphrase
        coreDataFolder.nodePassphraseSignature = createdFolder.nodePassphraseSignature
        coreDataFolder.signatureEmail = createdFolder.nameSignatureEmail // Created at the same time as the nameSignatureEmail, no distinction between them
        coreDataFolder.nodeHashKey = createdFolder.nodeHashKey

        coreDataFolder.state = .active
        coreDataFolder.mimeType = Folder.mimeType
        coreDataFolder.createdDate = Date()
        coreDataFolder.modifiedDate = Date()

        return coreDataFolder
    }
}
