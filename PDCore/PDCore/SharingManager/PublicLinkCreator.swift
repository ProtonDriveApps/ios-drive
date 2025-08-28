// Copyright (c) 2024 Proton AG
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
import PDClient
import CoreData

public protocol PublicLinkCreator {
    func createPublicLink(
        share: ShareIdentifier,
        permissions: ShareURLMeta.Permissions
    ) async throws -> PublicLinkIdentifier
}

public final class RemoteCachingPublicLinkCreator: PublicLinkCreator {
    private let client: Client
    private let storage: StorageManager
    private let signersKitFactory: SignersKitFactoryProtocol

    public init(client: Client, storage: StorageManager, signersKitFactory: SignersKitFactoryProtocol) {
        self.client = client
        self.storage = storage
        self.signersKitFactory = signersKitFactory
    }

    public func createPublicLink(
        share identifier: ShareIdentifier,
        permissions: ShareURLMeta.Permissions
    ) async throws -> PublicLinkIdentifier {
        let context = storage.backgroundContext
        let modulusSRP = try await client.getModulusSRP()

        let parameters = try await context.perform {
            guard let share = Share.fetch(id: identifier.id, in: context) else {
                throw Share.InvalidState(message: "Missing required Share.")
            }
            return try self.getNewShareURLParameters(
                share: share,
                modulus: modulusSRP.modulus,
                modulusID: modulusSRP.modulusID,
                permissions: permissions
            )
        }

        let shareURLMeta = try await client.createShareURL(shareID: identifier.id, parameters: parameters)
        Log.info("SharingManager.onObtainedShare, did create a new shareURL. Share: \(shareURLMeta.shareID), shareURL: \(shareURLMeta.shareURLID)", domain: .sharing)

        return try await context.perform {
            let shareURL = self.storage.updateShareURL(shareURLMeta, in: context)
            try context.saveOrRollback()
            return shareURL.identifier
        }
    }

    private func getNewShareURLParameters(
        share: Share,
        modulus: String,
        modulusID: String,
        permissions: ShareURLMeta.Permissions
    ) throws -> NewShareURLParameters {
        let addressID = try share.getAddressID()
        let randomPassword = Decryptor.randomPassword(ofSize: Constants.minSharedLinkRandomPasswordSize)
        let currentAddressKey = try signersKitFactory.make(forAddressID: addressID).addressKey.publicKey
        let encryptedPassword = try Encryptor.encrypt(randomPassword, key: currentAddressKey)

        let srpRandomPassword = try Decryptor.srpForPassword(randomPassword, modulus: modulus)
        let srpPasswordSalt = srpRandomPassword.salt.base64EncodedString()
        let srpPasswordVerifier = srpRandomPassword.verifier.base64EncodedString()

        let shareDecryptionKeys = try share.getShareCreatorDecryptionKeys()
        let shareSessionKey = try Decryptor.decryptSessionKey(share.passphrase.forceUnwrap(), decryptionKeys: shareDecryptionKeys)
        let bcryptedRandomPassword = try Decryptor.bcryptPassword(randomPassword)
        let shareKeyPacket = try Decryptor.encryptSessionKey(shareSessionKey, with: bcryptedRandomPassword.hash).base64EncodedString()
        let sharePasswordSalt = bcryptedRandomPassword.salt.base64EncodedString()

        let parameters = NewShareURLParameters(
            expirationTime: nil,
            expirationDuration: nil,
            maxAccesses: Constants.maxAccesses,
            creatorEmail: share.creator.forceUnwrap(),
            permissions: permissions,
            URLPasswordSalt: srpPasswordSalt,
            sharePasswordSalt: sharePasswordSalt,
            SRPVerifier: srpPasswordVerifier,
            SRPModulusID: modulusID,
            flags: .newRandomPassword,
            sharePassphraseKeyPacket: shareKeyPacket,
            password: encryptedPassword,
            name: nil
        )
        return parameters
    }

    func update(_ shareURLMeta: ShareURLMeta, in moc: NSManagedObjectContext) -> ShareURL {
        let shareUrl: ShareURL = self.storage.unique(with: Set([shareURLMeta.shareURLID]), uniqueBy: "id", in: moc).first!
        shareUrl.fulfillShareURL(with: shareURLMeta)

        let shares: [ShareObj] = self.storage.unique(with: Set([shareURLMeta.shareID]), in: moc)
        let share = shares.first!
        shareUrl.setValue(share, forKey: #keyPath(ShareURL.share))
        share.shareUrls.insert(shareUrl)

        return shareUrl
    }
}
