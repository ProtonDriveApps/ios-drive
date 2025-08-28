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

public protocol PublicLinkUpdater {
    func updatePublicLink(_ identifier: PublicLinkIdentifier, with details: UpdateShareURLDetails) async throws
}

public final class RemoteCachingPublicLinkUpdater: PublicLinkUpdater {

    private let client: Client
    private let storage: StorageManager
    private let signersKitFactory: SignersKitFactoryProtocol

    public init(client: Client, storage: StorageManager, signersKitFactory: SignersKitFactoryProtocol) {
        self.client = client
        self.storage = storage
        self.signersKitFactory = signersKitFactory
    }

    public func updatePublicLink(_ identifier: PublicLinkIdentifier, with details: UpdateShareURLDetails) async throws {
        Log.info("SharingManager.updateSecureLink, will update a secure link details \(identifier)", domain: .sharing)
        let context = storage.backgroundContext

        let shareURL = try await context.perform {
            guard let shareURL = ShareURL.fetch(id: identifier.id, in: context) else {
                throw ShareURL.InvalidState(message: "No ShareURL with id: \(identifier.id) found")
            }
            return shareURL
        }

        let shareUrlMeta = try await updateShareURL(shareURL: shareURL, details: details)

        return try await context.perform {
            self.storage.updateShareURL(shareUrlMeta, in: context)
            try context.saveOrRollback()
        }
    }

    /// Internal for unit tests only, returns metadata
    private func updateShareURL(
        shareURL: ShareURL,
        details: UpdateShareURLDetails
    ) async throws -> ShareUrlMeta {
        let expirationParameter = makeExpirationParameter(duration: details.duration)
        let passwordParameter = try await makePasswordParameter(shareURL: shareURL, password: details.password)
        let permissionParameter = makePermissionParameter(permissions: details.permission)
        let parameters = EditShareURLUpdateParameters(
            expirationParameters: expirationParameter,
            passwordParameters: passwordParameter,
            permissionParameters: permissionParameter
        )
        
        let (shareID, shareURLID) = await storage.backgroundContext.perform {
            return (shareURL.share.id, shareURL.id)
        }
        return try await client.updateShareURL(shareURLID: shareURLID, shareID: shareID, parameters: parameters)
    }
    
    private func makeExpirationParameter(duration: UpdateShareURLDetails.Duration) -> EditShareURLExpiration? {
        switch duration {
        case .unchanged:
            return nil
        case .nonExpiring:
            return .init(expirationDuration: nil)
        case .expiring(let timeInterval):
            return .init(expirationDuration: Int(timeInterval))
        }
    }
    
    private func makePasswordParameter(
        shareURL: ShareURL,
        password: UpdateShareURLDetails.Password
    ) async throws -> EditShareURLPassword? {
        switch password {
        case .unchanged:
            return nil
        case .updated(let newPassword):
            guard newPassword.count >= Constants.minSharedLinkRandomPasswordSize,
                  newPassword.count <= Constants.maxSharedLinkPasswordLength else {
                throw DriveError("The new Public Link password does not fit Public Link password requirements.")
            }
            let modulusResponse = try await client.getModulusSRP()
            let context = storage.backgroundContext
            return try await context.perform {
                try self.makeUpdatedPassword(
                    share: shareURL.share,
                    urlPassword: newPassword,
                    modulus: modulusResponse.modulus,
                    modulusID: modulusResponse.modulusID
                )
            }
        }
    }
    
    private func makeUpdatedPassword(share: Share, urlPassword: String, modulus: String, modulusID: String) throws -> EditShareURLPassword {
        let addressID = try share.getAddressID()
        let currentAddressKey = try signersKitFactory.make(forAddressID: addressID).addressKey.publicKey
        let encryptedPassword = try Encryptor.encrypt(urlPassword, key: currentAddressKey)

        let srpRandomPassword = try Decryptor.srpForPassword(urlPassword, modulus: modulus)
        let srpPasswordSalt = srpRandomPassword.salt.base64EncodedString()
        let srpPasswordVerifier = srpRandomPassword.verifier.base64EncodedString()

        let shareDecryptionKeys = try share.getShareCreatorDecryptionKeys()
        let shareSessionKey = try Decryptor.decryptSessionKey(share.passphrase.forceUnwrap(), decryptionKeys: shareDecryptionKeys)
        let bcryptedRandomPassword = try Decryptor.bcryptPassword(urlPassword)
        let shareKeyPacket = try Decryptor.encryptSessionKey(shareSessionKey, with: bcryptedRandomPassword.hash).base64EncodedString()
        let sharePasswordSalt = bcryptedRandomPassword.salt.base64EncodedString()

        let flag: ShareURLMeta.Flags = urlPassword.count == Constants.minSharedLinkRandomPasswordSize ? .newRandomPassword : .newCustomPassword

        return EditShareURLPassword(
            urlPasswordSalt: srpPasswordSalt,
            sharePasswordSalt: sharePasswordSalt,
            srpVerifier: srpPasswordVerifier,
            srpModulusID: modulusID,
            flags: flag,
            sharePassphraseKeyPacket: shareKeyPacket,
            encryptedUrlPassword: encryptedPassword
        )
    }
    
    private func makePermissionParameter(permissions: UpdateShareURLDetails.Permissions) -> EditShareURLPermissions? {
        switch permissions {
        case .unchanged:
            return nil
        case .read:
            return .init(permissions: .read)
        case .readAndWrite:
            return .init(permissions: [.read, .write])
        }
    }
}
